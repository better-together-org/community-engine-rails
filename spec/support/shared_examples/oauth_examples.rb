# frozen_string_literal: true

# Shared examples for OAuth authentication flows
RSpec.shared_examples 'OAuth authentication' do |provider|
  let(:auth_hash) do
    OmniAuth::AuthHash.new({
                             provider: provider.to_s,
                             uid: '123456',
                             info: {
                               email: 'test@example.com',
                               name: 'Test User',
                               nickname: 'testuser',
                               image: 'https://avatars.example.com/u/123456?v=4'
                             },
                             credentials: {
                               token: 'access_token_123',
                               secret: 'secret_456',
                               expires_at: 1.hour.from_now.to_i
                             },
                             extra: {
                               raw_info: {
                                 login: 'testuser',
                                 html_url: "https://#{provider}.com/testuser"
                               }
                             }
                           })
  end

  context "when #{provider} OAuth succeeds" do
    before do
      request.env['omniauth.auth'] = auth_hash
    end

    it 'creates new user with correct attributes' do
      expect do
        get provider
      end.to change { BetterTogether.user_class.count }.by(1)
                                                       .and change(BetterTogether::PersonPlatformIntegration, :count).by(1)
                                                                                                                     .and change(
                                                                                                                       BetterTogether::Person, :count
                                                                                                                     ).by(1)

      user = BetterTogether.user_class.last
      expect(user.email).to eq('test@example.com')
      expect(user.person.name).to eq('Test User')
      expect(user.person.handle).to eq('testuser')

      integration = user.person_platform_integrations.first
      expect(integration.provider).to eq(provider.to_s)
      expect(integration.uid).to eq('123456')
      expect(integration.access_token).to eq('access_token_123')
    end

    it 'signs in user and redirects correctly' do
      get provider

      user = BetterTogether.user_class.last
      expect(controller.current_user).to eq(user)
      expect(response).to redirect_to(controller.edit_user_registration_path)
    end

    it 'sets success flash message' do
      get provider

      expect(flash[:success]).to include(provider.to_s.capitalize)
    end
  end

  context "when #{provider} OAuth fails" do
    before do
      allow(BetterTogether.user_class).to receive(:from_omniauth).and_return(nil)
      request.env['omniauth.auth'] = auth_hash
    end

    it 'sets alert flash message and redirects to registration' do
      get provider

      expect(flash[:alert]).to include(provider.to_s.capitalize)
      expect(response).to redirect_to(controller.new_user_registration_path)
    end
  end
end

# Shared examples for OAuth model behavior
RSpec.shared_examples 'OAuth integration model' do
  include BetterTogether::DeviseSessionHelpers

  let(:platform) { configure_host_platform }
  let(:integration) { build(:person_platform_integration, platform: platform) }

  it 'belongs to user, person, and platform' do
    expect(integration).to respond_to(:user)
    expect(integration).to respond_to(:person)
    expect(integration).to respond_to(:platform)
  end

  it 'has required OAuth fields' do
    expect(integration).to respond_to(:provider)
    expect(integration).to respond_to(:uid)
    expect(integration).to respond_to(:access_token)
    expect(integration).to respond_to(:access_token_secret)
    expect(integration).to respond_to(:expires_at)
  end

  it 'has profile information fields' do
    expect(integration).to respond_to(:handle)
    expect(integration).to respond_to(:name)
    expect(integration).to respond_to(:profile_url)
    expect(integration).to respond_to(:image_url)
  end
end

# Shared examples for OAuth token management
RSpec.shared_examples 'OAuth token management' do
  let(:integration) do
    create(:person_platform_integration,
           access_token: 'current_token',
           refresh_token: 'refresh_token_123',
           expires_at: 1.hour.ago)
  end

  describe '#expired?' do
    it 'correctly identifies expired tokens' do
      expect(integration.expired?).to be(true)

      integration.update(expires_at: 1.hour.from_now)
      expect(integration.expired?).to be(false)

      integration.update(expires_at: nil)
      expect(integration.expired?).to be(false)
    end
  end

  describe '#token' do
    before do
      allow(integration).to receive(:renew_token!)
    end

    it 'renews token if expired' do
      expect(integration).to receive(:renew_token!)
      integration.token
    end

    it 'returns current token if not expired' do
      integration.update(expires_at: 1.hour.from_now)
      expect(integration).not_to receive(:renew_token!)
      expect(integration.token).to eq('current_token')
    end
  end
end
