# frozen_string_literal: true

require 'rails_helper'

# @hermetic
RSpec.describe BetterTogether::TenantPlatformProvisioningService do
  let(:base_params) do
    {
      name: 'Test Tenant',
      host_url: "https://tenant-#{SecureRandom.hex(6)}.example.com",
      time_zone: 'UTC'
    }
  end

  describe '.call' do
    context 'without admin params' do
      it 'provisions a platform with community and domain' do
        result = described_class.call(**base_params)

        expect(result).to be_success
        expect(result.errors).to be_blank
        expect(result.platform).to be_persisted
        expect(result.platform.name).to eq('Test Tenant')
        expect(result.platform.host).to be(false)
        expect(result.platform.csp_img_src).to include('https://*.tile.openstreetmap.org')
        expect(result.platform.csp_img_src).not_to include('https://unpkg.com')
        expect(result.community).to be_present
        expect(result.admin_user).to be_nil
      end

      it 'auto-creates a PlatformDomain via model callback' do
        result = described_class.call(**base_params)

        expect(result.domain).to be_present
        expect(result.domain.hostname).to be_present
      end
    end

    context 'with admin params' do
      let(:admin_params) do
        {
          email: "admin-#{SecureRandom.hex(4)}@example.com",
          password: 'Secur3Pass!wordXYZ',
          name: 'Admin User'
        }
      end

      it 'creates an admin user with platform and community roles' do
        result = described_class.call(**base_params, admin: admin_params)

        expect(result).to be_success
        expect(result.admin_user).to be_persisted
        expect(result.admin_user.email).to eq(admin_params[:email])

        person = result.admin_user.person
        expect(person.person_platform_memberships.joins(:role)
          .where(better_together_roles: { identifier: 'platform_steward' })
          .where(joinable: result.platform)).to exist
        expect(person.person_community_memberships.joins(:role)
          .where(better_together_roles: { identifier: 'community_governance_council' })
          .where(joinable: result.community)).to exist
      end
    end

    context 'when idempotent' do
      it 'returns the existing platform on re-run with same host_url' do
        first  = described_class.call(**base_params)
        second = described_class.call(**base_params)

        expect(second).to be_success
        expect(second.platform.id).to eq(first.platform.id)
      end
    end

    context 'when platform params are invalid' do
      it 'returns a failure result without raising' do
        result = described_class.call(name: '', host_url: '', time_zone: 'UTC')

        expect(result).not_to be_success
        expect(result.errors).to be_present
      end
    end
  end
end
