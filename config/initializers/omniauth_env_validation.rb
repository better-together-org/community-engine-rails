# frozen_string_literal: true

# Validate OAuth provider environment variables at boot time
# This helps catch configuration issues early in development and production

Rails.application.config.after_initialize do
  # Define required environment variables for each OAuth provider
  oauth_providers = BetterTogether::IdentityProviders.registry.transform_values(&:env_vars)

  missing_vars = []

  oauth_providers.each do |provider, required_vars|
    required_vars.each do |var|
      if ENV[var].blank?
        missing_vars << { provider: provider, var: var }
        Rails.logger.warn "[OAuth Configuration] #{var} not configured - #{provider} OAuth will not work"
      end
    end
  end

  # In development, also log successful configuration
  if Rails.env.development? && missing_vars.empty?
    Rails.logger.info '[OAuth Configuration] All OAuth providers properly configured'
  end

  # In production, raise an error if critical OAuth providers are missing
  if Rails.env.production? && missing_vars.any?
    providers_missing = missing_vars.map { |m| m[:provider] }.uniq
    Rails.logger.error "[OAuth Configuration] CRITICAL: OAuth not configured for: #{providers_missing.join(', ')}"

    # Uncomment to make missing OAuth config a fatal error in production:
    # raise "OAuth configuration missing for: #{providers_missing.join(', ')}"
  end
end
