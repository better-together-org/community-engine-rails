# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformDomain do
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

  describe 'steward-requested domains' do
    let(:zone) { managed_platform_setup(associate: false).operator_platform.primary_platform_domain.hostname }
    let(:platform) { create(:better_together_platform, type: 'BetterTogether::HostedPlatform') }

    let(:stewarded_domain) do
      ->(hostname, **attrs) { described_class.new(platform:, hostname:, steward_requested: true, **attrs) }
    end

    it 'accepts a single label under the host zone and starts it inactive, not primary' do
      domain = stewarded_domain.call("club.#{zone}", active: true, primary_flag: true)

      expect(domain).to be_valid
      expect(domain.active).to be(false)
      expect(domain.primary_flag).to be(false)
    end

    it 'accepts a single label under a configured zone' do
      allow(BetterTogether).to receive(:platform_domain_zones).and_return(['communityengine.app'])

      expect(stewarded_domain.call('club.communityengine.app')).to be_valid
    end

    it 'rejects hostnames outside every allowed zone' do
      domain = stewarded_domain.call('club.elsewhere.test')

      expect(domain).not_to be_valid
      expect(domain.errors[:hostname]).to be_present
    end

    it 'rejects nested labels under a zone' do
      expect(stewarded_domain.call("a.b.#{zone}")).not_to be_valid
    end

    it 'rejects the zone itself' do
      expect(stewarded_domain.call(zone)).not_to be_valid
    end

    it 'rejects reserved labels' do
      domain = stewarded_domain.call("www.#{zone}")

      expect(domain).not_to be_valid
      expect(domain.errors[:hostname]).to include('is a reserved name')
    end

    it 'does not apply to records the controller did not flag' do
      expect(described_class.new(platform:, hostname: 'club.elsewhere.test', active: true)).to be_valid
    end

    it 'blocks a steward from activating a domain or renaming an active one' do
      active = create(:better_together_platform_domain, platform:, hostname: "live.#{zone}", active: true)
      inactive = create(:better_together_platform_domain, platform:, hostname: "wait.#{zone}", active: false)

      active.steward_requested = true
      active.hostname = "moved.#{zone}"
      expect(active).not_to be_valid
      expect(active.errors[:hostname]).to be_present

      inactive.steward_requested = true
      inactive.active = true
      expect(inactive).not_to be_valid
      expect(inactive.errors[:active]).to be_present
    end
  end
end
