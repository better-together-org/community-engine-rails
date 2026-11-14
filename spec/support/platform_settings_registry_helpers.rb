# frozen_string_literal: true

# Registers platform settings for one example and restores the registry afterwards.
module PlatformSettingsRegistryHelpers
  def with_registered_platform_settings
    registry = BetterTogether::PlatformSettingsRegistry
    saved = registry.definitions.dup
    yield
  ensure
    registry.definitions.replace(saved)
  end

  def register_sample_analytics_settings
    BetterTogether.register_platform_setting(
      'sample_analytics.measurement_id',
      label: 'Measurement ID', hint: 'Looks like G-ABC123.', pattern: /\AG-[A-Z0-9]+\z/,
      env_fallback: 'SAMPLE_ANALYTICS_ID', group_label: 'Sample analytics'
    )
    BetterTogether.register_platform_setting('sample_analytics.anonymize_ip', type: :boolean, label: 'Anonymize IP',
                                                                              default: true)
    BetterTogether.register_platform_setting('sample_analytics.api_secret', label: 'API secret', secret: true)
  end
end

RSpec.configure do |config|
  config.include PlatformSettingsRegistryHelpers
  config.around(:each, :platform_settings) do |example|
    with_registered_platform_settings do
      register_sample_analytics_settings
      example.run
    end
  end
end
