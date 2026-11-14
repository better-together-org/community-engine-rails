# frozen_string_literal: true

require 'rails_helper'

# P0-2: administrative rights end at the platform that granted them.
RSpec.describe BetterTogether::Member do
  let!(:host_platform) { configure_host_platform }
  let(:tenant_platform) { create(:better_together_platform, :public) }
  let(:manager_role) { BetterTogether::Role.find_by!(identifier: 'platform_manager') }
  let(:tenant_steward) do
    user = create(:better_together_user, :confirmed)
    BetterTogether::PersonPlatformMembership.create!(
      member: user.person, joinable: tenant_platform, role: manager_role, status: 'active'
    )
    user.person.expire_permission_cache!
    user
  end

  around do |example|
    Current.set(platform: tenant_platform, host_platform:) { example.run }
  end

  it 'lets a tenant steward manage their own platform' do
    expect(tenant_steward.person.platform_manager?).to be(true)
  end

  it 'does not make a tenant steward a manager of the host platform' do
    expect(tenant_steward.person.platform_manager?(host_platform)).to be(false)
    expect(tenant_steward.person.host_platform_manager?).to be(false)
  end

  it 'denies tenant stewards the host only seed screens' do
    policy = BetterTogether::SeedPolicy.new(tenant_steward, BetterTogether::Seed)

    expect([policy.index?, policy.create?, policy.destroy?]).to all(be(false))
  end

  it 'denies the host steward nothing on the host platform' do
    host_user = create(:better_together_user, :confirmed, :platform_manager)
    Current.set(platform: host_platform) do
      expect(host_user.person.host_platform_manager?).to be(true)
    end
  end

  it 'keys the permission cache by record id, not identifier' do
    person = tenant_steward.person
    a = person.send(:cache_key_for, :permitted_to, 'manage_platform', tenant_platform)
    b = person.send(:cache_key_for, :permitted_to, 'manage_platform', host_platform)

    expect(a).to include(tenant_platform.id)
    expect(a).not_to eq(b)
  end
end
