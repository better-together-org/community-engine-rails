# frozen_string_literal: true

# Helpers for testing OmniAuth authentication flows in isolation
module OmniauthTestHelpers
  # Provides RSpec configuration for isolating OmniAuth state
  # Must be called at describe/context level using metadata tag :omniauth
  #
  # This module automatically isolates OmniAuth global state for tests tagged with :omniauth
  # The isolation is applied via an around hook that saves and restores OmniAuth configuration
  #
  # Usage: Tag describe/context blocks with :omniauth metadata
  #   RSpec.describe 'OAuth flows', :omniauth do
  #     # OmniAuth state is automatically isolated for each example
  #   end
  # rubocop:disable Metrics/AbcSize
  def self.included(base)
    base.around(:each, :omniauth) do |example|
      # Save original OmniAuth state
      original_test_mode = OmniAuth.config.test_mode
      original_mocks = OmniAuth.config.mock_auth.to_hash.dup
      original_on_failure = OmniAuth.config.on_failure

      # Run the example
      example.run

      # Restore original state
      OmniAuth.config.test_mode = original_test_mode
      OmniAuth.config.mock_auth = OmniAuth::AuthHash.new(original_mocks)
      OmniAuth.config.on_failure = original_on_failure
    end
  end
  # rubocop:enable Metrics/AbcSize

  # Creates a GitHub OAuth auth hash with unique identifiers
  # @param email [String] email address for the OAuth user
  # @param uid [String] OAuth provider UID
  # @param options [Hash] additional options to customize the auth hash
  # @return [OmniAuth::AuthHash] configured auth hash
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def github_oauth_hash(email: unique_email, uid: unique_oauth_uid, **options)
    OmniAuth::AuthHash.new({
                             provider: 'github',
                             uid: uid,
                             info: {
                               email: email,
                               name: options[:name] || 'Test User',
                               nickname: options[:nickname] || unique_username,
                               image: options[:image] || 'https://avatars.githubusercontent.com/u/123456?v=4'
                             },
                             credentials: {
                               token: options[:token] || "github_token_#{SecureRandom.hex(8)}",
                               secret: options[:secret] || "github_secret_#{SecureRandom.hex(8)}",
                               expires_at: options[:expires_at] || 1.hour.from_now.to_i
                             },
                             extra: {
                               raw_info: {
                                 login: options[:nickname] || unique_username,
                                 html_url: options[:profile_url] || "https://github.com/#{unique_username}"
                               }
                             }
                           })
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
end
