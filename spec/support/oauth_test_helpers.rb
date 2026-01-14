# frozen_string_literal: true

module OAuthTestHelpers # rubocop:todo Metrics/ModuleLength
  # Generate a mock OAuth auth hash for testing
  # rubocop:todo Metrics/PerceivedComplexity
  # rubocop:todo Metrics/MethodLength
  # rubocop:todo Metrics/AbcSize
  # rubocop:todo Lint/CopDirectiveSyntax
  def mock_oauth_auth_hash(provider, options = {}) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
    # rubocop:enable Lint/CopDirectiveSyntax
    provider_name = provider.to_s

    OmniAuth::AuthHash.new({
      provider: provider_name,
      uid: options[:uid] || Faker::Number.number(digits: 8).to_s,
      info: {
        email: options[:email] || Faker::Internet.email,
        name: options[:name] || Faker::Name.name,
        nickname: options[:nickname] || Faker::Internet.username,
        image: options[:image] || "https://avatars.#{provider_name}.com/u/#{options[:uid] || '123456'}?v=4"
      },
      credentials: {
        token: options[:token] || Faker::Crypto.sha256,
        secret: options[:secret] || Faker::Crypto.sha256,
        expires_at: options[:expires_at] || 1.hour.from_now.to_i
      },
      extra: {
        raw_info: {
          login: options[:nickname] || Faker::Internet.username,
          html_url: options[:profile_url] || "https://#{provider_name}.com/#{options[:nickname] || 'testuser'}"
        }
      }
    }.deep_merge(options[:extra] || {}))
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/PerceivedComplexity

  # Generate GitHub specific auth hash
  def mock_github_auth_hash(options = {}) # rubocop:todo Metrics/MethodLength
    github_options = {
      uid: '123456',
      email: 'github.user@example.com',
      name: 'GitHub User',
      nickname: 'githubuser',
      image: 'https://avatars.githubusercontent.com/u/123456?v=4',
      profile_url: 'https://github.com/githubuser',
      extra: {
        extra: {
          raw_info: {
            login: 'githubuser',
            html_url: 'https://github.com/githubuser',
            type: 'User',
            public_repos: 42,
            followers: 100,
            following: 50
          }
        }
      }
    }.merge(options)

    mock_oauth_auth_hash(:github, github_options)
  end

  # Generate Facebook specific auth hash
  def mock_facebook_auth_hash(options = {}) # rubocop:todo Metrics/MethodLength
    facebook_options = {
      uid: '123456789',
      email: 'facebook.user@example.com',
      name: 'Facebook User',
      nickname: 'facebookuser',
      image: 'https://graph.facebook.com/123456789/picture',
      profile_url: 'https://facebook.com/facebookuser',
      extra: {
        extra: {
          raw_info: {
            id: '123456789',
            email: 'facebook.user@example.com',
            first_name: 'Facebook',
            last_name: 'User',
            verified: true
          }
        }
      }
    }.merge(options)

    mock_oauth_auth_hash(:facebook, facebook_options)
  end

  # Generate Google specific auth hash
  def mock_google_auth_hash(options = {}) # rubocop:todo Metrics/MethodLength
    google_options = {
      uid: '123456789012345678901',
      email: 'google.user@example.com',
      name: 'Google User',
      nickname: 'googleuser',
      image: 'https://lh3.googleusercontent.com/a/default-user',
      profile_url: 'https://plus.google.com/123456789012345678901',
      extra: {
        extra: {
          raw_info: {
            sub: '123456789012345678901',
            email: 'google.user@example.com',
            name: 'Google User',
            given_name: 'Google',
            family_name: 'User',
            email_verified: true,
            locale: 'en'
          }
        }
      }
    }.merge(options)

    mock_oauth_auth_hash(:google_oauth2, google_options)
  end

  # Setup OmniAuth test mode with mock auth
  def setup_omniauth_test_mode(provider, auth_hash = nil)
    OmniAuth.config.test_mode = true
    auth_hash ||= case provider.to_sym
                  when :github
                    mock_github_auth_hash
                  when :facebook
                    mock_facebook_auth_hash
                  when :google, :google_oauth2
                    mock_google_auth_hash
                  else
                    mock_oauth_auth_hash(provider)
                  end

    OmniAuth.config.mock_auth[provider.to_sym] = auth_hash
    auth_hash
  end

  # Teardown OmniAuth test mode
  def teardown_omniauth_test_mode(provider = nil)
    if provider
      OmniAuth.config.mock_auth[provider.to_sym] = nil
    else
      OmniAuth.config.mock_auth = {}
    end
    OmniAuth.config.test_mode = false
  end

  # Simulate OAuth failure
  def simulate_oauth_failure(provider, error_type = :invalid_credentials)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[provider.to_sym] = error_type
  end

  # Generate minimal auth hash (missing some fields)
  def mock_minimal_oauth_auth_hash(provider, options = {})
    OmniAuth::AuthHash.new({
                             provider: provider.to_s,
                             uid: options[:uid] || '123456',
                             info: options[:info] || {},
                             credentials: {
                               token: options[:token] || 'minimal_token'
                             }
                           })
  end

  # Ensure external platforms exist for OAuth tests
  def ensure_external_platforms_exist # rubocop:todo Metrics/MethodLength
    # Create external platforms needed for OAuth testing
    oauth_platforms = [
      { identifier: 'github', name: 'GitHub' },
      { identifier: 'google', name: 'Google' },
      { identifier: 'facebook', name: 'Facebook' },
      { identifier: 'linkedin', name: 'LinkedIn' }
    ]

    oauth_platforms.each do |platform_attrs|
      next if BetterTogether::Platform.external.find_by(identifier: platform_attrs[:identifier])

      BetterTogether::Platform.create!(
        platform_attrs.merge(
          external: true,
          url: "https://#{platform_attrs[:identifier]}.com",
          privacy: 'public',
          time_zone: 'UTC'
        )
      )
    end
  end

  # Setup complete OAuth test environment
  def setup_oauth_test_environment(provider, auth_hash = nil)
    # Ensure external platforms exist
    ensure_external_platforms_exist

    # Setup OmniAuth test mode
    setup_omniauth_test_mode(provider, auth_hash)
  end

  # Simplified mock for controller tests - matches RailsApps pattern
  # rubocop:todo Metrics/PerceivedComplexity
  # rubocop:todo Metrics/MethodLength
  # rubocop:todo Metrics/AbcSize
  # rubocop:todo Lint/CopDirectiveSyntax
  def simple_oauth_mock(provider, options = {}) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
    # rubocop:enable Lint/CopDirectiveSyntax
    defaults = {
      'provider' => provider.to_s,
      'uid' => options[:uid] || '123456',
      'info' => {
        'email' => options[:email] || "#{provider}.user@example.com",
        'name' => options[:name] || "#{provider.to_s.capitalize} User",
        'nickname' => options[:nickname] || "#{provider}user",
        'image' => options[:image] || "https://#{provider}.com/avatar.jpg"
      },
      'credentials' => {
        'token' => options[:token] || 'mock_token_123',
        'secret' => options[:secret] || 'mock_secret_456',
        'expires_at' => options[:expires_at] || 1.hour.from_now.to_i
      }
    }

    # Provider-specific adjustments
    case provider.to_sym
    when :github
      defaults['info']['urls'] = { 'GitHub' => 'https://github.com/testuser' }
      defaults.delete('secret') # GitHub doesn't use secret
    when :google, :google_oauth2
      defaults['extra'] = {
        'raw_info' => {
          'sub' => defaults['uid'],
          'email' => defaults['info']['email'],
          'email_verified' => true
        }
      }
      defaults.delete('secret') # Google doesn't use secret
    end

    defaults.deep_merge(options[:extra_data] || {})
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/PerceivedComplexity
end

# Include the helper methods in RSpec
RSpec.configure do |config|
  config.include OAuthTestHelpers
end
