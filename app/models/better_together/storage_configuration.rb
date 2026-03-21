# frozen_string_literal: true

module BetterTogether
  # Represents a storage backend configuration for a platform.
  # Supports local disk, Amazon S3, and generic S3-compatible services (e.g. Garage).
  #
  # Credentials are encrypted at rest using Rails ActiveRecord::Encryption.
  # A Platform may have many StorageConfigurations but designates one as primary
  # via platforms.storage_configuration_id.
  class StorageConfiguration < ApplicationRecord
    self.table_name = 'better_together_storage_configurations'

    SERVICE_TYPES = %w[local amazon s3_compatible].freeze

    # Encrypt S3 credentials at rest
    encrypts :access_key_id
    encrypts :secret_access_key

    belongs_to :platform, class_name: 'BetterTogether::Platform'

    validates :name, presence: true
    validates :service_type, presence: true, inclusion: { in: SERVICE_TYPES }
    validates :bucket, presence: true, if: :s3_service?
    validates :region, presence: true, if: :amazon?
    validates :access_key_id, presence: true, if: :s3_service?
    validates :secret_access_key, presence: true, if: :s3_service?
    validates :endpoint, presence: true, if: :s3_compatible?
    validates :endpoint, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true

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
      case service_type
      when 'local'
        { service: 'Disk', root: Rails.root.join('storage').to_s }
      when 'amazon', 's3_compatible'
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
        end
        config
      end
    end

    # Returns a symbol usable as a key in storage.yml / Active Storage registry
    def storage_key
      "platform_#{platform_id}"
    end
  end
end
