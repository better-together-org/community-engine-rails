# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonPlatformIntegration, '.attributes_from_omniauth' do
  let(:auth) do
    OmniAuth::AuthHash.new(
      provider: 'github', uid: 'u' * 200,
      info: { email: 'a@example.test', name: 'A' },
      credentials: { token: 'access-secret', refresh_token: 'refresh-secret', expires_at: nil },
      extra: { id_token: 'jwt-secret', raw_info: { login: 'a', access_token: 'nested-secret' } }
    )
  end

  it 'keeps profile data but no tokens in the stored payload', :aggregate_failures do
    stored = described_class.attributes_from_omniauth(auth)[:auth]

    expect(stored.to_json).not_to match(/access-secret|refresh-secret|jwt-secret|nested-secret/)
    expect(stored.dig('extra', 'raw_info', 'login')).to eq('a')
  end

  it 'accepts a 200 character uid' do
    expect(build(:person_platform_integration, uid: 'u' * 200)).to be_valid
  end
end
