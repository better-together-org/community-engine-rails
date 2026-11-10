# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformIdentityProvider do
  subject(:provider) { build(:better_together_platform_identity_provider) }

  it { is_expected.to be_valid }

  it 'rejects an unregistered strategy' do
    provider.strategy = 'myspace'

    expect(provider).not_to be_valid
  end

  it 'requires the provider platform to be external' do
    provider.provider_platform = create(:better_together_platform, external: false)

    expect(provider).not_to be_valid
  end

  it 'allows one row per platform and provider platform' do
    provider.save!
    dup = build(:better_together_platform_identity_provider, platform: provider.platform,
                                                             provider_platform: provider.provider_platform)

    expect(dup).not_to be_valid
  end

  it 'encrypts the client secret at rest' do
    provider.save!
    raw = described_class.connection.select_value(
      "SELECT client_secret FROM better_together_platform_identity_providers WHERE id = '#{provider.id}'"
    )

    expect(raw).not_to include(provider.client_secret)
  end
end
