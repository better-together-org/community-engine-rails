# frozen_string_literal: true

# Create external platforms for OAuth providers
module BetterTogether
  # Seeds for creating external OAuth provider platforms
  class ExternalPlatformSeeds
    OAUTH_PROVIDERS = [
      {
        name: 'GitHub',
        url: 'https://github.com',
        identifier: 'github',
        description: 'GitHub OAuth Provider',
        time_zone: 'UTC'
      },
      {
        name: 'Google',
        url: 'https://accounts.google.com',
        identifier: 'google',
        description: 'Google OAuth Provider',
        time_zone: 'UTC'
      },
      {
        name: 'Facebook',
        url: 'https://www.facebook.com',
        identifier: 'facebook',
        description: 'Facebook OAuth Provider',
        time_zone: 'UTC'
      },
      {
        name: 'LinkedIn',
        url: 'https://linkedin.com',
        identifier: 'linkedin',
        description: 'LinkedIn OAuth Provider',
        time_zone: 'UTC'
      }
    ].freeze

    def self.create! # rubocop:todo Metrics/MethodLength
      OAUTH_PROVIDERS.each do |provider_attrs|
        platform = Platform.find_or_initialize_by(
          identifier: provider_attrs[:identifier],
          external: true
        )

        if platform.new_record?
          platform.assign_attributes(
            name: provider_attrs[:name],
            url: provider_attrs[:url],
            description: provider_attrs[:description],
            time_zone: provider_attrs[:time_zone],
            external: true,
            host: false,
            privacy: 'public'
          )

          platform.save!
          Rails.logger.info "Created external platform: #{platform.name}"
        else
          Rails.logger.info "External platform already exists: #{platform.name}"
        end
      end
    end
  end
end

# Create the external platforms
BetterTogether::ExternalPlatformSeeds.create!
