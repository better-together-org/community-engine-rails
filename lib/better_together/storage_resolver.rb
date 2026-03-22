# frozen_string_literal: true

module BetterTogether
  # Resolves the active storage configuration for a platform or the host application.
  #
  # Resolution order:
  #   1. Platform's active_storage_configuration (if FK is set)
  #   2. Environment variables: ACTIVE_STORAGE_SERVICE + AWS_* / S3_*
  #   3. Hardcoded default: local disk storage
  #
  # Usage:
  #   resolver = BetterTogether::StorageResolver.new(platform)
  #   resolver.service_name    # => :local | :amazon | :storage_config_<uuid>
  #   resolver.active_config   # => StorageConfiguration or nil
  #   resolver.env_based?      # => true if falling back to env vars
  #   resolver.to_active_storage_config  # => hash suitable for ActiveStorage registration
  class StorageResolver
    SUPPORTED_ENV_SERVICES = %w[local amazon s3_compatible].freeze

    def initialize(platform = nil)
      @platform = platform
    end

    # Returns the StorageConfiguration AR record if one is explicitly set on the platform.
    def active_config
      return nil unless @platform.present?

      @platform.active_storage_configuration
    end

    # True when the resolver is falling back to env-var-based configuration.
    def env_based?
      active_config.nil?
    end

    # Returns a symbol for use as the Active Storage service key.
    def service_name
      return active_config.storage_key.to_sym if active_config.present?

      env_service_name.to_sym
    end

    # Returns a configuration hash compatible with ActiveStorage::Service.build.
    # When platform has an explicit config, the hash comes from the model.
    # When env-based, it is synthesised from environment variables.
    def to_active_storage_config
      return active_config.to_active_storage_config if active_config.present?

      env_storage_config
    end

    # Registers this resolver's service with Active Storage so Rails can use it.
    # Call this from an initializer (once per platform or once globally from env).
    def register!
      key = service_name
      return if ActiveStorage::Blob.service.try(:name) == key.to_s
      return if ActiveStorage::Service.send(:lookup_registry).key?(key.to_s)

      config = to_active_storage_config
      ActiveStorage::Service.configure(key, config)
    end

    # Summarises the effective configuration (without secrets) for display in admin UI.
    def summary
      active_config.present? ? platform_config_summary : env_summary
    end

    private

    def env_service_name
      value = ENV.fetch('ACTIVE_STORAGE_SERVICE', 'local')
      unless SUPPORTED_ENV_SERVICES.include?(value)
        Rails.logger.warn(
          "[BetterTogether::StorageResolver] Unknown ACTIVE_STORAGE_SERVICE='#{value}'; " \
          "falling back to 'local'. Supported: #{SUPPORTED_ENV_SERVICES.join(', ')}"
        )
        return 'local'
      end
      value
    end

    def platform_config_summary
      {
        source: :platform_config,
        config_id: active_config.id,
        name: active_config.name,
        service_type: active_config.service_type,
        endpoint: active_config.endpoint,
        bucket: active_config.bucket,
        region: active_config.region
      }
    end

    def env_summary
      {
        source: :env,
        service_type: env_service_name,
        endpoint: ENV.fetch('S3_ENDPOINT', nil),
        bucket: ENV.fetch('S3_BUCKET_NAME', ENV.fetch('FOG_DIRECTORY', nil)),
        region: ENV.fetch('S3_REGION', ENV.fetch('AWS_REGION', 'us-east-1'))
      }
    end

    def env_storage_config
      env_service_name == 'local' ? local_disk_config : s3_env_config
    end

    def local_disk_config
      { service: 'Disk', root: Rails.root.join('storage').to_s }
    end

    def s3_env_config
      config = {
        service: 'S3',
        access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID', nil),
        secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY', nil),
        region: ENV.fetch('S3_REGION', ENV.fetch('AWS_REGION', 'us-east-1')),
        bucket: ENV.fetch('S3_BUCKET_NAME', ENV.fetch('FOG_DIRECTORY', nil))
      }
      endpoint = ENV.fetch('S3_ENDPOINT', nil)
      if endpoint.present?
        config[:endpoint] = endpoint
        config[:force_path_style] = true
      end
      config
    end
  end
end
