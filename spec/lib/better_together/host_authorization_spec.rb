# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::HostAuthorization, :skip_host_setup do
  describe '.env_hosts' do
    it 'reads APP_HOSTS and the ALLOWED_HOSTS alias, trimmed and de-duplicated' do
      env = { 'APP_HOSTS' => 'a.test, b.test,', 'ALLOWED_HOSTS' => 'b.test,c.test' }

      expect(described_class.env_hosts(env)).to eq(%w[a.test b.test c.test])
    end

    it 'is empty when neither is set' do
      expect(described_class.env_hosts({})).to eq([])
    end
  end

  describe '.allowed?' do
    let(:platform) { create(:better_together_platform, host: false, host_url: 'http://club.hosts.test') }

    before { platform }

    it 'allows an active platform domain, with or without a port' do
      expect(described_class.allowed?('club.hosts.test')).to be(true)
      expect(described_class.allowed?('club.hosts.test:3000')).to be(true)
    end

    it 'refuses an unknown hostname and a blank one' do
      expect(described_class.allowed?('nobody.hosts.test')).to be(false)
      expect(described_class.allowed?('')).to be(false)
    end

    it 'refuses an inactive domain' do
      platform.platform_domains.update_all(active: false) # rubocop:disable Rails/SkipsModelValidations
      BetterTogether::PlatformDomain.clear_resolution_cache! if BetterTogether::PlatformDomain.respond_to?(:clear_resolution_cache!)
      Rails.cache.clear

      expect(described_class.allowed?('club.hosts.test')).to be(false)
    end
  end

  describe '.install!' do
    it 'adds the matcher to an allow-list that is already in force, once' do
      hosts = ['example.test']

      expect(described_class.install!(hosts)).to be(true)
      expect(described_class.install!(hosts)).to be(false)
      expect(hosts).to eq(['example.test', described_class.matcher])
    end

    it 'leaves an empty list unrestricted' do
      hosts = []

      expect(described_class.install!(hosts)).to be(false)
      expect(hosts).to be_empty
    end

    it 'works with the Rails host authorization matcher' do
      create(:better_together_platform, host: false, host_url: 'http://open.hosts.test')
      permissions = ActionDispatch::HostAuthorization::Permissions.new(['example.test', described_class.matcher])

      expect(permissions.allows?('open.hosts.test:3000')).to be(true)
      expect(permissions.allows?('example.test')).to be(true)
      expect(permissions.allows?('evil.hosts.test')).to be(false)
    end
  end
end
