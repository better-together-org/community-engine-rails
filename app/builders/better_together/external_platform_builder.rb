# frozen_string_literal: true

# app/builders/better_together/external_platform_builder.rb

module BetterTogether
  # Builder to create external OAuth provider platforms
  class ExternalPlatformBuilder < Builder
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

    class << self
      def seed_data
        puts "Creating #{OAUTH_PROVIDERS.length} external OAuth provider platforms..."

        OAUTH_PROVIDERS.each do |provider_attrs|
          create_external_platform(provider_attrs)
        end

        puts '✓ Successfully processed all OAuth providers'
      end

      # Clear existing external platforms - Use with caution!
      def clear_existing
        count = Platform.external.count
        Platform.external.delete_all
        puts "✓ Cleared #{count} existing external platforms"
      end

      private

      def create_external_platform(provider_attrs)
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
          puts "  ✓ Created external platform: #{platform.name}"
        else
          puts "  - External platform already exists: #{platform.name}"
        end

        platform
      end
    end
  end
end
