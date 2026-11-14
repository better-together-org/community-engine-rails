# frozen_string_literal: true

# Configures Active Storage service based on the host platform's active StorageConfiguration
# or falls back to environment variables.
#
# Resolution order:
#   1. Platform#active_storage_configuration (database-persisted, platform-specific)
#   2. ACTIVE_STORAGE_SERVICE env var + AWS_* / S3_* env vars
#   3. local disk (hardcoded fallback)
#
# This initializer runs after the DB is available (config.after_initialize).
# The service configured here overrides the value in config/storage.yml at startup.
Rails.application.config.after_initialize do
  # Skip if Active Storage is not loaded (e.g. in asset-only processes)
  next unless defined?(ActiveStorage)

  # Skip if the database is unavailable (e.g. during asset precompile)
  next unless ActiveRecord::Base.with_connection { |conn| conn.table_exists?('better_together_platforms') } rescue false # rubocop:disable Style/RescueModifier

  host_platform = BetterTogether::Platform.find_by(host: true)
  resolver = BetterTogether::StorageResolver.new(host_platform)

  next if resolver.env_based? # env-based config is already handled by config/storage.yml + env vars

  # Blobs created for a platform are stamped with that platform's service (see Storage::TenantService);
  # the host platform's config also becomes the default for blobs created without a platform.
  resolver.rebind_default!
rescue StandardError => e
  # Do not crash startup on storage configuration errors — log and continue with default
  Rails.logger.error("[BetterTogether::StorageResolver] Failed to configure storage: #{e.message}")
end
