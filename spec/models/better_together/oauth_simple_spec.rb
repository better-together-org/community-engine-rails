# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Simple OAuth Flow' do # rubocop:todo RSpec/DescribeClass
  include BetterTogether::DeviseSessionHelpers

  let(:platform) { configure_host_platform }
  let(:community) { platform.community }
  let!(:github_platform) do
    BetterTogether::Platform.find_or_create_by!(identifier: 'github') do |github|
      github.external = true
      github.host = false
      github.name = 'GitHub'
      github.url = 'https://github.com'
      github.privacy = 'public'
      github.time_zone = 'UTC'
    end
  end

  before do
    platform # Ensure platform is created
  end

  describe 'OAuth user creation from scratch' do
    let(:auth_hash) do
      OmniAuth::AuthHash.new({
                               provider: 'github',
                               uid: '123456',
                               info: {
                                 email: 'test@example.com',
                                 name: 'Test User',
                                 nickname: 'testuser',
                                 image: 'https://avatars.githubusercontent.com/u/123456?v=4'
                               },
                               credentials: {
                                 token: 'github_access_token_123',
                                 expires_at: 1.hour.from_now.to_i
                               },
                               extra: {
                                 raw_info: {
                                   html_url: 'https://github.com/testuser',
                                   login: 'testuser'
                                 }
                               }
                             })
    end

    it 'creates a new user with OAuth integration' do
      expect do
        user = BetterTogether.user_class.from_omniauth(
          person_platform_integration: nil,
          auth: auth_hash,
          current_user: nil
        )

        expect(user).to be_persisted
        expect(user.email).to eq('test@example.com')
        expect(user.person).to be_present

        # Should find and assign the correct external platform
        integration = user.person_platform_integrations.first
        expect(integration.platform).to be_external
        expect(integration.platform.identifier).to eq('github')
        expect(integration.platform.name).to eq('GitHub')

        # Should not use the host platform
        expect(integration.platform).not_to eq(platform)
        expect(user.person.name).to eq('Test User')

        # Check PersonPlatformIntegration was created
        integration = BetterTogether::PersonPlatformIntegration.find_by(
          provider: 'github',
          uid: '123456'
        )
        expect(integration).to be_present
        expect(integration.user).to eq(user)
        expect(integration.person).to eq(user.person)
        expect(integration.platform).to eq(github_platform) # Should use external platform
        expect(integration.access_token).to eq('github_access_token_123')
      end.to change(BetterTogether.user_class, :count).by(1)
                                                      .and change(BetterTogether::Person, :count).by(1)
                                                                                                 .and change(
                                                                                                   # rubocop:todo Layout/LineLength
                                                                                                   BetterTogether::PersonPlatformIntegration, :count
                                                                                                   # rubocop:enable Layout/LineLength
                                                                                                 ).by(1)
    end

    it 'handles existing PersonPlatformIntegration' do
      # Create existing integration
      existing_user = create(:better_together_user)
      existing_integration = create(:better_together_person_platform_integration,
                                    provider: 'github',
                                    uid: '123456',
                                    user: existing_user,
                                    person: existing_user.person,
                                    platform: platform)

      expect do
        user = BetterTogether.user_class.from_omniauth(
          person_platform_integration: existing_integration,
          auth: auth_hash,
          current_user: nil
        )

        expect(user).to eq(existing_user)
        expect(user).to be_persisted

        # Integration should be updated, not recreated
        existing_integration.reload
        expect(existing_integration.access_token).to eq('github_access_token_123')
      end.not_to change(BetterTogether.user_class, :count)
      expect { nil }.not_to change(BetterTogether::Person, :count)
      expect { nil }.not_to change(BetterTogether::PersonPlatformIntegration, :count)
    end

    it 'links integration to current signed-in user' do
      current_user = create(:better_together_user)

      user = nil
      expect do
        user = BetterTogether.user_class.from_omniauth(
          person_platform_integration: nil,
          auth: auth_hash,
          current_user: current_user
        )
      end.to change(BetterTogether::PersonPlatformIntegration, :count).by(1)

      expect(user).to eq(current_user)

      # Should create integration linked to current user
      integration = BetterTogether::PersonPlatformIntegration.find_by(
        provider: 'github',
        uid: '123456'
      )
      expect(integration).to be_present
      expect(integration.user).to eq(current_user)
      expect(integration.person).to eq(current_user.person)

      expect { nil }.not_to change(BetterTogether.user_class, :count)
      expect { nil }.not_to change(BetterTogether::Person, :count)
    end
  end

  describe 'PersonPlatformIntegration attributes processing' do
    let(:auth_hash) do
      OmniAuth::AuthHash.new({
                               provider: 'github',
                               uid: '654321',
                               info: {
                                 email: 'oauth@example.com',
                                 name: 'OAuth User',
                                 nickname: 'oauthuser',
                                 image: 'https://avatars.githubusercontent.com/u/654321?v=4',
                                 urls: { 'GitHub' => 'https://github.com/oauthuser' }
                               },
                               credentials: {
                                 token: 'new_access_token',
                                 secret: 'new_secret',
                                 expires_at: 2.hours.from_now.to_i
                               },
                               extra: {
                                 raw_info: {
                                   html_url: 'https://github.com/oauthuser',
                                   login: 'oauthuser',
                                   name: 'OAuth User'
                                 }
                               }
                             })
    end

    it 'extracts correct attributes from auth hash' do
      attributes = BetterTogether::PersonPlatformIntegration.attributes_from_omniauth(auth_hash)

      expect(attributes[:provider]).to eq('github')
      expect(attributes[:uid]).to eq('654321')
      expect(attributes[:access_token]).to eq('new_access_token')
      expect(attributes[:access_token_secret]).to eq('new_secret')
      expect(attributes[:handle]).to eq('oauthuser')
      expect(attributes[:name]).to eq('OAuth User')
      expect(attributes[:image_url]).to be_a(URI)
      expect(attributes[:profile_url]).to eq('https://github.com/oauthuser')
      expect(attributes[:expires_at]).to be_a(Time)
      expect(attributes[:auth]).to eq(auth_hash.to_hash)
    end

    it 'handles missing optional fields gracefully' do
      minimal_auth = OmniAuth::AuthHash.new({
                                              provider: 'github',
                                              uid: '999999',
                                              info: {
                                                email: 'minimal@example.com'
                                                # No name, nickname, image, etc.
                                              },
                                              credentials: {
                                                token: 'minimal_token'
                                                # No expires_at
                                              }
                                              # No extra section
                                            })

      attributes = BetterTogether::PersonPlatformIntegration.attributes_from_omniauth(minimal_auth)

      expect(attributes[:provider]).to eq('github')
      expect(attributes[:uid]).to eq('999999')
      expect(attributes[:access_token]).to eq('minimal_token')
      expect(attributes[:handle]).to be_nil
      # OmniAuth automatically sets name to email when name is not provided
      expect(attributes[:name]).to eq('minimal@example.com')
      expect(attributes[:image_url]).to be_nil
      expect(attributes[:profile_url]).to be_nil
      expect(attributes[:expires_at]).to be_nil
    end
  end
end
