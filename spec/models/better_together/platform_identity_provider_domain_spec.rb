# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformIdentityProviderDomain do
  let(:platform) { create(:better_together_platform) }
  let(:external) { create(:better_together_platform, external: true) }
  let(:domain) do
    BetterTogether::PlatformDomain.create!(platform:, hostname: 'one.example.test', active: true)
  end
  let(:first_config) { create(:better_together_platform_identity_provider, platform:, provider_platform: external) }
  let(:second_config) do
    create(:better_together_platform_identity_provider, platform:, provider_platform: create(:better_together_platform, external: true))
  end

  it 'allows a domain on one configuration' do
    expect(described_class.new(platform_identity_provider: first_config, platform_domain: domain)).to be_valid
  end

  it 'rejects the same domain twice on one configuration' do
    described_class.create!(platform_identity_provider: first_config, platform_domain: domain)

    expect(described_class.new(platform_identity_provider: first_config, platform_domain: domain)).not_to be_valid
  end

  it 'rejects a domain already claimed by another configuration of the same strategy', :aggregate_failures do
    described_class.create!(platform_identity_provider: first_config, platform_domain: domain)
    claim = described_class.new(platform_identity_provider: second_config, platform_domain: domain)

    expect(claim).not_to be_valid
    expect(claim.errors[:platform_domain]).to be_present
  end

  it 'removes its join rows when the configuration is destroyed' do
    described_class.create!(platform_identity_provider: first_config, platform_domain: domain)

    expect { first_config.destroy }.to change(described_class, :count).by(-1)
  end
end
