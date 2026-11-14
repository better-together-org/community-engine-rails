# frozen_string_literal: true

module BetterTogether
  # Represents a storage backend configuration for a platform.
  # Supports local disk, Amazon S3, and generic S3-compatible services (e.g. Garage).
  #
  # Credentials are encrypted at rest using Rails ActiveRecord::Encryption.
  # A Platform may have many StorageConfigurations but designates one as primary
  # via platforms.storage_configuration_id.
  class StorageConfiguration < ApplicationRecord # rubocop:disable Metrics/ClassLength
    self.table_name = 'better_together_storage_configurations'

    SERVICE_TYPES = %w[local amazon s3_compatible].freeze
    HEALTH_STATUSES = %w[ok failed].freeze
    S3_COMPATIBLE_CHECKSUM_OPTIONS = {
      request_checksum_calculation: 'when_required',
      response_checksum_validation: 'when_required'
    }.freeze

    # Encrypt S3 credentials at rest
    encrypts :access_key_id
    encrypts :secret_access_key

    # Not PlatformScoped: every read/write goes through the owning Platform's
    # `has_many :storage_configurations` association or `Platform#
    # active_storage_configuration` (belongs_to, keyed by
    # platforms.storage_configuration_id) rather than a bare class-level
    # query — no `StorageConfiguration.find`/`.first`/`.all` exists anywhere
    # in the app. The one exception is Storage::TenantRegistry, which loads a row
    # by the id inside a blob's service_name. Holds encrypted S3 credentials, so
    # any other call site should go through the platform association.
    belongs_to :platform, class_name: 'BetterTogether::Platform'

    validates :name, presence: true
    validates :service_type, presence: true, inclusion: { in: SERVICE_TYPES }
    validates :bucket, presence: true, if: :s3_service?
    validates :region, presence: true, if: :amazon?
    validates :access_key_id, presence: true, if: :s3_service?
    validates :secret_access_key, presence: true, if: :s3_service?
    validates :endpoint, presence: true, if: :s3_compatible?
    validates :endpoint, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true
    # The host platform's operator may point at an internal store (for example http://garage:3900).
    # A tenant platform may not, because its endpoint is chosen by someone other than the host operator.
    validate :endpoint_host_safe, unless: -> { platform&.host? }
    validate :bucket_not_used_by_another_platform, if: :s3_service?
    validates :health_status, inclusion: { in: HEALTH_STATUSES }, allow_nil: true

    scope :s3_services, -> { where.not(service_type: 'local') }
    scope :for_platform, ->(platform) { where(platform:) }

    def self.service_type_options
      SERVICE_TYPES.map { |t| [I18n.t("better_together.storage.service_types.#{t}"), t] }
    end

    def local?
      service_type == 'local'
    end

    def amazon?
      service_type == 'amazon'
    end

    def s3_compatible?
      service_type == 's3_compatible'
    end

    def s3_service?
      amazon? || s3_compatible?
    end

    # Returns the options hash suitable for configuring an Active Storage service
    def to_active_storage_config
      local? ? local_storage_config : s3_storage_config
    end

    # Returns a stable string key for the Active Storage service registry.
    # Keyed on the config record ID so swapping configs never silently redirects
    # existing blobs to a different backend.
    def storage_key
      "storage_config_#{id}"
    end

    # Runs a write, read and delete probe and records the result on the row.
    def test_connection!
      result = Storage::ConnectionTest.new(self).call
      update_columns(health_status: result.ok? ? 'ok' : 'failed', health_message: result.message, # rubocop:disable Rails/SkipsModelValidations
                     health_checked_at: Time.current)
      result
    end

    # Replaces the key pair only after the new pair passes a connection test, so a typo cannot lock
    # a platform out of its bucket. Returns true on success and adds an error on failure.
    # The key pair is an encrypted attribute; it is only ever assigned through the model.
    def rotate_credentials!(**credentials)
      candidate = dup.tap { |c| c.assign_attributes(credentials.slice(:access_key_id, :secret_access_key)) }
      result = Storage::ConnectionTest.new(candidate).call
      return rotate_failed(result) unless result.ok? && candidate.valid?

      persist_rotation(candidate)
    end

    # Bytes stored on this configuration's service (see Storage::Usage).
    def used_bytes
      Storage::Usage.bytes_for(self)
    end

    private

    def persist_rotation(candidate) # rubocop:disable Naming/PredicateMethod
      update!(candidate.slice(:access_key_id, :secret_access_key)
                       .merge(health_status: 'ok', health_message: 'ok', health_checked_at: Time.current))
      ActiveStorage::Blob.services.forget(storage_key) if ActiveStorage::Blob.services.respond_to?(:forget)
      true
    end

    def endpoint_host_safe
      BetterTogether::SafeFederationUrlValidator
        .new(attributes: [:endpoint])
        .validate_each(self, :endpoint, endpoint)
    end

    def rotate_failed(result) # rubocop:disable Naming/PredicateMethod
      errors.add(:base, :connection_failed, message: "connection test failed (#{result.message})")
      false
    end

    # One bucket belongs to one platform. Without this, two platforms could share a bucket and
    # see each other's files, since blob keys carry no platform prefix.
    def bucket_not_used_by_another_platform
      return if bucket.blank?

      taken = self.class.s3_services.where.not(platform_id:).where(bucket:)
                  .any? { |other| same_store?(other) }
      errors.add(:bucket, :taken) if taken
    end

    def same_store?(other)
      normalize_endpoint(other.endpoint) == normalize_endpoint(endpoint)
    end

    def normalize_endpoint(value)
      value.to_s.strip.downcase.chomp('/')
    end

    def local_storage_config
      { service: 'Disk', root: Rails.root.join('storage').to_s }
    end

    def s3_storage_config
      config = {
        service: 'S3',
        access_key_id:,
        secret_access_key:,
        region: region.presence || 'us-east-1',
        bucket:
      }
      if endpoint.present?
        config[:endpoint] = endpoint
        config[:force_path_style] = true
        # Newer aws-sdk-s3 defaults to CRC checksums that S3-compatible stores
        # such as Garage do not return in a form the SDK accepts.
        config.merge!(S3_COMPATIBLE_CHECKSUM_OPTIONS)
      end
      config
    end
  end
end
