# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformConnectionPolicy do
  subject(:policy) { described_class.new(user, platform_connection) }

  let(:host_platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
  let(:platform_connection) do
    create(:better_together_platform_connection, :active, source_platform: host_platform)
  end
  let(:user) { nil }

  describe 'for a network admin' do
    let(:user) { create(:better_together_user, :network_admin) }

    it 'allows index, show, and update' do
      expect(policy.index?).to be true
      expect(policy.show?).to be true
      expect(policy.update?).to be true
    end
  end

  describe 'for a regular user' do
    let(:user) { create(:better_together_user) }

    it 'denies index, show, and update' do
      expect(policy.index?).to be false
      expect(policy.show?).to be false
      expect(policy.update?).to be false
    end
  end

  describe 'for an approval-only operator' do
    let(:user) { create(:better_together_user, :confirmed) }

    before do
      permission = BetterTogether::ResourcePermission.find_by(identifier: 'approve_network_connections')
      role = create(:better_together_role, :platform_role)
      BetterTogether::RoleResourcePermission.create!(role:, resource_permission: permission)
      host_platform = BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host)
      create(:better_together_person_platform_membership, member: user.person, joinable: host_platform, role:)
    end

    it 'allows approve but denies generic update' do
      expect(policy.approve?).to be true
      expect(policy.update?).to be false
    end
  end

  describe 'cross-tenant isolation' do
    let(:tenant_platform) { create(:better_together_platform, :public) }
    let(:tenant_operator) { create(:better_together_user, :confirmed) }

    before do
      permission = BetterTogether::ResourcePermission.find_by(identifier: 'manage_network_connections')
      role = create(:better_together_role, :platform_role)
      BetterTogether::RoleResourcePermission.create!(role:, resource_permission: permission)
      create(:better_together_person_platform_membership, member: tenant_operator.person, joinable: tenant_platform,
                                                          role:)
    end

    it 'denies managing a connection whose local platform is a different tenant, including the host' do
      policy = described_class.new(tenant_operator, platform_connection)

      expect(policy.index?).to be false
      expect(policy.show?).to be false
      expect(policy.update?).to be false
      expect(policy.approve?).to be false
      expect(policy.suspend?).to be false
      expect(policy.destroy?).to be false
      expect(policy.rotate_secret?).to be false
    end

    it 'allows managing a connection whose local platform is their own tenant' do
      own_connection = create(:better_together_platform_connection, :active, source_platform: tenant_platform)
      policy = described_class.new(tenant_operator, own_connection)

      expect(policy.update?).to be true
    end

    it "excludes other tenants' connections from the resolved scope" do
      resolved = described_class::Scope.new(tenant_operator, BetterTogether::PlatformConnection).resolve

      expect(resolved).not_to include(platform_connection)
    end
  end

  describe 'when the rollout is disabled for the platform' do
    let(:user) { create(:better_together_user, :network_admin) }

    before do
      host_platform = BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host)
      host_platform.update!(feature_gate_rollouts: { 'platform_federation_tools' => 'off' })
    end

    it 'denies access even to otherwise authorized operators' do
      expect(policy.index?).to be false
      expect(policy.show?).to be false
      expect(policy.update?).to be false
    end
  end
end
