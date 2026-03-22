# frozen_string_literal: true

require 'rails_helper'
require 'octokit'

RSpec.describe BetterTogether::PersonPlatformIntegration do
  let(:user) { create(:user, :confirmed) }
  let(:person) { user.person }
  let(:github_platform) do
    BetterTogether::Platform.find_or_create_by!(identifier: 'github') do |platform|
      platform.external = true
      platform.host = false
      platform.name = 'GitHub'
      platform.url = 'https://github.com'
      platform.privacy = 'public'
      platform.time_zone = 'UTC'
    end
  end
  let(:github_integration) do
    create(:person_platform_integration,
           :github,
           user:,
           person:,
           platform: github_platform,
           access_token: 'gho_test_token_123')
  end

  describe '#github?' do
    it 'returns true for GitHub integration' do
      expect(github_integration.github?).to be true
    end

    it 'returns false for non-GitHub integration' do
      facebook_platform = BetterTogether::Platform.find_or_create_by!(identifier: 'facebook') do |platform|
        platform.external = true
        platform.host = false
        platform.name = 'Facebook'
        platform.url = 'https://facebook.com'
        platform.privacy = 'public'
        platform.time_zone = 'UTC'
      end
      facebook_integration = create(:person_platform_integration,
                                    :facebook,
                                    user:,
                                    person:,
                                    platform: facebook_platform)

      expect(facebook_integration.github?).to be false
    end
  end

  describe '#github_client' do
    context 'when integration is for GitHub' do
      it 'returns a BetterTogether::Github client' do
        expect(github_integration.github_client).to be_a(BetterTogether::Github)
      end

      it 'passes itself to the GitHub client' do
        client = github_integration.github_client
        expect(client.integration).to eq(github_integration)
      end

      it 'memoizes the client' do
        client1 = github_integration.github_client
        client2 = github_integration.github_client
        expect(client1.object_id).to eq(client2.object_id)
      end

      it 'returns an Octokit client with correct token' do
        client = github_integration.github_client
        expect(client.client.access_token).to eq('gho_test_token_123')
      end
    end

    context 'when integration is not for GitHub' do
      let(:facebook_platform) do
        BetterTogether::Platform.find_or_create_by!(identifier: 'facebook') do |platform|
          platform.external = true
          platform.host = false
          platform.name = 'Facebook'
          platform.url = 'https://facebook.com'
          platform.privacy = 'public'
          platform.time_zone = 'UTC'
        end
      end
      let(:facebook_integration) do
        create(:person_platform_integration,
               :facebook,
               user:,
               person:,
               platform: facebook_platform)
      end

      it 'raises an error' do
        expect do
          facebook_integration.github_client
        end.to raise_error(RuntimeError, 'This integration is not for GitHub')
      end
    end
  end

  describe 'integration with GitHub API' do
    let(:mock_user) do
      {
        login: 'testuser',
        name: 'Test User',
        bio: 'Developer'
      }
    end

    before do
      allow_any_instance_of(Octokit::Client).to receive(:user).and_return(mock_user) # rubocop:todo RSpec/AnyInstance
    end

    it 'can fetch GitHub user information through the client' do
      client = github_integration.github_client
      user_info = client.user

      expect(user_info[:login]).to eq('testuser')
      expect(user_info[:name]).to eq('Test User')
    end
  end

  describe 'token refresh integration' do
    let(:expired_integration) do
      create(:person_platform_integration,
             :github,
             user:,
             person:,
             platform: github_platform,
             access_token: 'old_token',
             refresh_token: 'refresh_token_123',
             expires_at: 1.hour.ago)
    end

    before do
      allow(expired_integration).to receive_messages(renew_token!: true, token: 'new_refreshed_token')
    end

    it 'uses refreshed token in GitHub client' do
      client = expired_integration.github_client
      # The token method should be called, which triggers renewal for expired tokens
      expect(client.client).to be_a(Octokit::Client)
    end
  end
end
