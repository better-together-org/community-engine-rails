# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonPlatformIntegration do
  let(:platform) { configure_host_platform }
  let(:community) { platform.community }

  before do
    platform # Ensure platform is created
  end

  describe 'validations' do
    let(:user) { create(:user) }
    let(:person) { user.person }
    let(:github_platform) { create(:better_together_platform, :external, identifier: 'github') }

    describe 'provider validation' do
      it 'validates presence of provider' do
        integration = build(:person_platform_integration, provider: nil)
        expect(integration).not_to be_valid
        expect(integration.errors[:provider]).to include("can't be blank")
      end

      it 'validates provider is in allowed list' do
        integration = build(:person_platform_integration, provider: 'invalid_provider')
        expect(integration).not_to be_valid
        expect(integration.errors[:provider]).to include('invalid_provider is not a supported OAuth provider')
      end

      it 'accepts valid providers' do
        BetterTogether::PersonPlatformIntegration::PROVIDERS.keys.each do |provider|
          integration = build(:person_platform_integration, provider: provider.to_s, platform: github_platform)
          expect(integration).to be_valid
        end
      end
    end

    describe 'uid validation' do
      it 'validates presence of uid' do
        integration = build(:person_platform_integration, uid: nil)
        expect(integration).not_to be_valid
        expect(integration.errors[:uid]).to include("can't be blank")
      end

      it 'validates uniqueness of uid scoped to provider' do
        existing = create(:person_platform_integration, provider: 'github', uid: '123456', platform: github_platform)
        duplicate = build(:person_platform_integration, provider: 'github', uid: '123456', platform: github_platform)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:uid]).to include('has already been linked to another account')
      end

      it 'allows same uid for different providers' do
        facebook_platform = create(:better_together_platform, :external, identifier: 'facebook')
        github_integration = create(:person_platform_integration, provider: 'github', uid: '123456', platform: github_platform)
        facebook_integration = build(:person_platform_integration, provider: 'facebook', uid: '123456', platform: facebook_platform)

        expect(facebook_integration).to be_valid
      end
    end

    describe 'access_token validation' do
      it 'validates presence of access_token on create' do
        integration = build(:person_platform_integration, access_token: nil)
        expect(integration).not_to be_valid
        expect(integration.errors[:access_token]).to include("can't be blank")
      end

      it 'allows nil access_token on update' do
        integration = create(:person_platform_integration, access_token: 'initial_token', platform: github_platform)
        integration.access_token = nil

        # Should be valid on update (validation only runs on :create)
        expect(integration.valid?).to be true
      end
    end

    describe 'user validation' do
      it 'validates presence of user' do
        integration = build(:person_platform_integration, user: nil)
        expect(integration).not_to be_valid
        expect(integration.errors[:user]).to include("can't be blank")
      end
    end
  end

  describe '.attributes_from_omniauth' do
    let(:github_auth_hash) do
      OmniAuth::AuthHash.new({
                               provider: 'github',
                               uid: '123456',
                               info: {
                                 email: 'test@example.com',
                                 name: 'Test User',
                                 nickname: 'testuser',
                                 image: 'https://avatars.githubusercontent.com/u/123456?v=4',
                                 urls: {
                                   GitHub: 'https://github.com/testuser'
                                 }
                               },
                               credentials: {
                                 token: 'github_access_token_123',
                                 secret: 'github_secret_456',
                                 expires_at: 1.hour.from_now.to_i
                               }
                             })
    end

    it 'extracts correct attributes from auth hash' do
      attributes = described_class.attributes_from_omniauth(github_auth_hash)

      expect(attributes[:provider]).to eq('github')
      expect(attributes[:uid]).to eq('123456')
      expect(attributes[:access_token]).to eq('github_access_token_123')
      expect(attributes[:access_token_secret]).to eq('github_secret_456')
      expect(attributes[:handle]).to eq('testuser')
      expect(attributes[:name]).to eq('Test User')
      expect(attributes[:image_url]).to be_a(URI)
      expect(attributes[:image_url].to_s).to eq('https://avatars.githubusercontent.com/u/123456?v=4')
      expect(attributes[:auth]).to eq(github_auth_hash.to_hash)
    end

    it 'handles expires_at when present' do
      expires_time = 2.hours.from_now.to_i
      github_auth_hash.credentials.expires_at = expires_time

      attributes = described_class.attributes_from_omniauth(github_auth_hash)

      expect(attributes[:expires_at]).to eq(Time.at(expires_time))
    end

    it 'handles expires_at when nil' do
      github_auth_hash.credentials.expires_at = nil

      attributes = described_class.attributes_from_omniauth(github_auth_hash)

      expect(attributes[:expires_at]).to be_nil
    end

    it 'handles missing optional fields' do
      minimal_auth_hash = OmniAuth::AuthHash.new({
                                                   provider: 'github',
                                                   uid: '123456',
                                                   info: {},
                                                   credentials: {
                                                     token: 'token123'
                                                   }
                                                 })

      attributes = described_class.attributes_from_omniauth(minimal_auth_hash)

      expect(attributes[:provider]).to eq('github')
      expect(attributes[:uid]).to eq('123456')
      expect(attributes[:access_token]).to eq('token123')
      expect(attributes[:handle]).to be_nil
      expect(attributes[:name]).to be_nil
      expect(attributes[:image_url]).to be_nil
    end

    it 'extracts profile_url from auth hash urls' do
      attributes = described_class.attributes_from_omniauth(github_auth_hash)

      expect(attributes[:profile_url]).to eq('https://github.com/testuser')
    end

    it 'extracts profile_url from extra raw_info' do
      auth_with_html_url = github_auth_hash.dup
      auth_with_html_url.extra = { raw_info: { html_url: 'https://github.com/testuser' } }

      attributes = described_class.attributes_from_omniauth(auth_with_html_url)

      expect(attributes[:profile_url]).to eq('https://github.com/testuser')
    end

    it 'handles invalid image URLs' do
      github_auth_hash.info.image = 'not-a-valid-url'

      expect do
        described_class.attributes_from_omniauth(github_auth_hash)
      end.not_to raise_error
    end
  end

  describe '.update_or_initialize' do
    let(:auth_hash) do
      OmniAuth::AuthHash.new({
                               provider: 'github',
                               uid: '123456',
                               info: { name: 'Updated Name' },
                               credentials: { token: 'new_token' }
                             })
    end

    context 'when person_platform_integration is present' do
      let(:existing_integration) { create(:person_platform_integration, name: 'Old Name') }

      it 'updates the existing integration' do
        expect(existing_integration).to receive(:update)
          .with(hash_including(name: 'Updated Name'))

        result = described_class.update_or_initialize(existing_integration, auth_hash)

        expect(result).to eq(existing_integration)
      end
    end

    context 'when person_platform_integration is nil' do
      it 'creates new integration with auth attributes' do
        allow(described_class).to receive(:attributes_from_omniauth)
          .with(auth_hash)
          .and_return({ provider: 'github', uid: '123456', name: 'New User' })

        expect(described_class).to receive(:new)
          .with(hash_including(provider: 'github', uid: '123456', name: 'New User'))
          .and_call_original

        result = described_class.update_or_initialize(nil, auth_hash)

        expect(result).to be_a(described_class)
        expect(result).to be_new_record
      end
    end
  end

  describe 'OAuth token management' do
    let(:integration) do
      create(:person_platform_integration,
             provider: 'github',
             access_token: 'current_token',
             refresh_token: 'refresh_token_123',
             expires_at: 1.hour.ago) # Expired
    end

    describe '#expired?' do
      it 'returns true when expires_at is in the past' do
        expect(integration.expired?).to be(true)
      end

      it 'returns false when expires_at is in the future' do
        integration.update(expires_at: 1.hour.from_now)
        expect(integration.expired?).to be(false)
      end

      it 'returns false when expires_at is nil' do
        integration.update(expires_at: nil)
        expect(integration.expired?).to be(false)
      end
    end

    describe '#supports_refresh?' do
      it 'returns true when both refresh_token and expires_at are present' do
        integration.update(refresh_token: 'refresh_token_123', expires_at: 1.hour.from_now)
        expect(integration.supports_refresh?).to be(true)
      end

      it 'returns false when refresh_token is nil' do
        integration.update(refresh_token: nil, expires_at: 1.hour.from_now)
        expect(integration.supports_refresh?).to be(false)
      end

      it 'returns false when expires_at is nil' do
        integration.update(refresh_token: 'refresh_token_123', expires_at: nil)
        expect(integration.supports_refresh?).to be(false)
      end

      it 'returns false when both are nil' do
        integration.update(refresh_token: nil, expires_at: nil)
        expect(integration.supports_refresh?).to be(false)
      end
    end

    describe '#token' do
      let(:mock_oauth_token) do
        double('OAuth2::AccessToken',
               token: 'refreshed_token',
               refresh_token: 'new_refresh_token',
               expires_at: 2.hours.from_now.to_i)
      end

      before do
        # Mock the strategy and OAuth2 token behavior
        allow(integration).to receive_messages(strategy: double('strategy', client: double('client')), current_token: double('token'))
        allow(integration.current_token).to receive(:refresh!).and_return(mock_oauth_token)
      end

      it 'renews token if expired' do
        expect(integration).to receive(:renew_token!)

        integration.token
      end

      it 'returns current access_token if not expired' do
        integration.update(expires_at: 1.hour.from_now)
        expect(integration).not_to receive(:renew_token!)

        expect(integration.token).to eq('current_token')
      end
    end

    describe '#renew_token!' do
      let(:mock_oauth_token) do
        double('OAuth2::AccessToken',
               token: 'refreshed_token',
               refresh_token: 'new_refresh_token',
               expires_at: 2.hours.from_now.to_i)
      end

      context 'when refresh is supported' do
        before do
          # Ensure refresh is supported
          integration.update(refresh_token: 'refresh_token_123', expires_at: 1.hour.ago)
          # Mock the OAuth2 token refresh behavior
          allow(integration).to receive(:current_token).and_return(double('token'))
          allow(integration.current_token).to receive(:refresh!).and_return(mock_oauth_token)
        end

        it 'refreshes token and updates attributes' do
          expect(integration).to receive(:update).with(
            access_token: 'refreshed_token',
            refresh_token: 'new_refresh_token',
            expires_at: be_within(1.second).of(Time.at(2.hours.from_now.to_i))
          )

          integration.renew_token!
        end

        it 'returns truthy value on success' do
          allow(integration).to receive(:update).and_return(true)
          expect(integration.renew_token!).to be_truthy
        end
      end

      context 'when refresh is not supported' do
        before do
          # Remove refresh_token to make refresh unsupported
          integration.update(refresh_token: nil)
        end

        it 'returns false without attempting refresh' do
          expect(integration).not_to receive(:current_token)
          expect(integration.renew_token!).to be(false)
        end

        it 'does not update the integration' do
          expect(integration).not_to receive(:update)
          integration.renew_token!
        end
      end

      context 'when OAuth2 refresh fails' do
        let(:oauth_error) { OAuth2::Error.new(double('response', status: 401, body: 'Invalid token')) }

        before do
          # Ensure refresh is supported
          integration.update(refresh_token: 'refresh_token_123', expires_at: 1.hour.ago)
          # Mock the OAuth2 token refresh to raise error
          allow(integration).to receive(:current_token).and_return(double('token'))
          allow(integration.current_token).to receive(:refresh!).and_raise(oauth_error)
        end

        it 'rescues OAuth2::Error and returns false' do
          expect(integration.renew_token!).to be(false)
        end

        it 'logs the error' do
          expect(Rails.logger).to receive(:error).with(
            a_string_including('Token refresh failed for github')
          )
          integration.renew_token!
        end

        it 'does not raise the error' do
          expect { integration.renew_token! }.not_to raise_error
        end
      end
    end

    describe '#current_token' do
      before do
        # Mock the OAuth2 client
        client = double('OAuth2::Client')
        strategy = double('strategy', client: client)
        allow(integration).to receive(:strategy).and_return(strategy)
      end

      it 'creates OAuth2::AccessToken with current credentials' do
        expect(OAuth2::AccessToken).to receive(:new)
          .with(
            integration.strategy.client,
            'current_token',
            refresh_token: 'refresh_token_123'
          )

        integration.current_token
      end
    end

    describe '#strategy' do
      let(:mock_strategy_instance) { double('strategy_instance') }
      let(:mock_strategy_class) { double('OmniAuth::Strategies::GitHub') }

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('GITHUB_CLIENT_ID', nil).and_return('client_id_123')
        allow(ENV).to receive(:fetch).with('GITHUB_CLIENT_SECRET', nil).and_return('client_secret_456')
        allow(OmniAuth::Strategies).to receive(:const_get).with('GitHub').and_return(mock_strategy_class)
        allow(mock_strategy_class).to receive(:new).and_return(mock_strategy_instance)
      end

      it 'creates strategy instance with environment credentials' do
        result = integration.strategy

        expect(OmniAuth::Strategies).to have_received(:const_get).with('GitHub')
        expect(mock_strategy_class).to have_received(:new)
          .with(nil, 'client_id_123', 'client_secret_456')
        expect(result).to eq(mock_strategy_instance)
      end
    end

    describe '#refresh_auth_hash' do
      let(:mock_strategy) do
        double('strategy',
               client: double('client'),
               auth_hash: { 'info' => { 'name' => 'Refreshed Name' } })
      end
      let(:mock_token) { double('token') }

      before do
        allow(integration).to receive_messages(strategy: mock_strategy, current_token: mock_token, expired?: true)
        allow(integration).to receive(:renew_token!)
      end

      it 'renews token if expired' do
        expect(integration).to receive(:renew_token!)
        expect(mock_strategy).to receive(:access_token=).with(mock_token)

        allow(integration.class).to receive(:attributes_from_omniauth)
          .and_return({ name: 'Refreshed Name' })
        allow(integration).to receive(:update)

        integration.refresh_auth_hash
      end

      it 'updates integration with refreshed auth data' do
        allow(integration).to receive(:renew_token!)
        allow(mock_strategy).to receive(:access_token=)

        expect(integration.class).to receive(:attributes_from_omniauth)
          .with(mock_strategy.auth_hash)
          .and_return({ name: 'Refreshed Name' })

        expect(integration).to receive(:update)
          .with({ name: 'Refreshed Name' })

        integration.refresh_auth_hash
      end
    end
  end

  describe 'provider scopes' do
    let!(:github_integration) { create(:person_platform_integration, provider: 'github') }
    let!(:facebook_integration) { create(:person_platform_integration, provider: 'facebook') }

    it 'has scope for each configured provider' do
      # Scopes are defined based on Devise.omniauth_configs
      # Check that scopes exist for configured providers
      Devise.omniauth_configs.each_key do |provider|
        expect(described_class).to respond_to(provider)
      end

      # Test the scope behavior if github is configured
      if Devise.omniauth_configs.key?(:github)
        expect(described_class.github).to include(github_integration)
        expect(described_class.github).not_to include(facebook_integration)
      end

      # Test the scope behavior if facebook is configured
      if Devise.omniauth_configs.key?(:facebook)
        expect(described_class.facebook).to include(facebook_integration)
        expect(described_class.facebook).not_to include(github_integration)
      end
    end
  end

  describe 'constants' do
    it 'defines PROVIDERS hash with correct mappings' do
      expect(described_class::PROVIDERS).to be_a(Hash)
      expect(described_class::PROVIDERS[:github]).to eq('Github')
      expect(described_class::PROVIDERS[:facebook]).to eq('Facebook')
      expect(described_class::PROVIDERS[:google_oauth2]).to eq('Google')
      expect(described_class::PROVIDERS[:linkedin]).to eq('Linkedin')
    end
  end
end
