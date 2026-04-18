# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformRuntimeContextResolver do
  describe '.for_host' do
    it 'resolves platform, domain, and tenant schema from a matching domain' do
      platform = create(:better_together_platform, tenant_schema: 'tenant_alpha')
      domain = create(:better_together_platform_domain, platform:, hostname: 'tenant-alpha.test')

      result = described_class.for_host('tenant-alpha.test')

      expect(result.platform).to eq(platform)
      expect(result.platform_domain).to eq(domain)
      expect(result.tenant_schema).to eq('tenant_alpha')
      expect(result.source).to eq(:platform_domain)
    end

    it 'falls back to the host platform when configured to do so' do
      host_platform = configure_host_platform
      host_platform.update!(tenant_schema: 'host_platform_schema')

      result = described_class.for_host('unknown-host.test')

      expect(result.platform).to eq(host_platform)
      expect(result.platform_domain).to be_nil
      expect(result.tenant_schema).to eq('host_platform_schema')
      expect(result.source).to eq(:host_platform)
    end

    it 'returns no platform when no match exists and fallback is disabled' do
      result = described_class.for_host('unknown-host.test', fallback_to_host: false)

      expect(result.platform).to be_nil
      expect(result.platform_domain).to be_nil
      expect(result.tenant_schema).to be_nil
      expect(result.source).to eq(:none)
    end
  end

  describe '.for_platform' do
    it 'resolves tenant schema from an explicit platform record' do
      platform = create(:better_together_platform, tenant_schema: 'tenant_explicit')

      result = described_class.for_platform(platform)

      expect(result.platform).to eq(platform)
      expect(result.tenant_schema).to eq('tenant_explicit')
      expect(result.source).to eq(:explicit_platform)
    end

    it 'does not surface tenant schema metadata for external peer platforms' do
      platform = create(:better_together_platform, :external)

      result = described_class.for_platform(platform)

      expect(result.platform).to eq(platform)
      expect(result.tenant_schema).to be_nil
      expect(result.source).to eq(:explicit_platform)
    end
  end
end
