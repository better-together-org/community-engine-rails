# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformDomain, type: :model do
  describe '.resolve' do
    it 'matches hostnames case-insensitively and without a trailing dot' do
      platform_domain = create(:better_together_platform_domain, hostname: 'Example.TEST')

      resolved = described_class.resolve('example.test.')

      expect(resolved).to eq(platform_domain)
    end

    it 'only resolves active domains' do
      create(:better_together_platform_domain, hostname: 'inactive.example.test', active: false)

      expect(described_class.resolve('inactive.example.test')).to be_nil
    end
  end

  describe '#url' do
    it 'uses the platform scheme with the domain hostname' do
      platform = create(:better_together_platform, host_url: "https://primary-#{SecureRandom.hex(4)}.example.test")
      platform_domain = create(:better_together_platform_domain, platform:, hostname: 'alias.example.test')

      expect(platform_domain.url).to eq('https://alias.example.test')
    end
  end

  describe 'validations' do
    it 'does not allow an inactive primary domain' do
      platform_domain = build(:better_together_platform_domain, :primary, active: false)

      expect(platform_domain).not_to be_valid
      expect(platform_domain.errors[:active]).to include('must be true for a primary domain')
    end
  end
end
