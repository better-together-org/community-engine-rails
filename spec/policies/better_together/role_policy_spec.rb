# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::RolePolicy, type: :policy do
  let(:manager_user) { create(:better_together_user, :platform_manager) }
  let(:normal_user) { create(:better_together_user) }

  let(:role) { create(:better_together_role) }
  let(:protected_role) { create(:better_together_role, protected: true) }

  describe '#index?' do
    subject { described_class.new(user, BetterTogether::Role).index? }

    context 'authenticated user' do
      let(:user) { normal_user }

      it { is_expected.to be true }
    end

    context 'guest' do
      let(:user) { nil }

      it { is_expected.to be false }
    end
  end

  describe '#show?' do
    subject { described_class.new(user, role).show? }

    context 'authenticated user' do
      let(:user) { normal_user }

      it { is_expected.to be true }
    end

    context 'guest' do
      let(:user) { nil }

      it { is_expected.to be false }
    end
  end

  describe '#create?' do
    subject { described_class.new(user, BetterTogether::Role).create? }

    context 'any user' do
      let(:user) { manager_user }

      it { is_expected.to be false }
    end
  end

  describe '#update?' do
    subject { described_class.new(user, role).update? }

    let(:role) { create(:better_together_role, :platform_role) }

    context 'platform manager' do
      let(:user) { manager_user }

      it { is_expected.to be true }
    end

    context 'normal user' do
      let(:user) { normal_user }

      it { is_expected.to be false }
    end

    context 'guest' do
      let(:user) { nil }

      it { is_expected.to be false }
    end
  end

  describe '#destroy? unprotected role' do
    subject { described_class.new(user, role).destroy? }

    # Use a platform-scoped role so the policy checks manage_platform_roles, which
    # platform_manager holds. The default factory uses RESOURCE_CLASSES.sample which
    # can pick community, making the test seed-dependent.
    let(:role) { create(:better_together_role, :platform_role) }

    context 'platform manager' do
      let(:user) { manager_user }

      it { is_expected.to be true }
    end

    context 'normal user' do
      let(:user) { normal_user }

      it { is_expected.to be false }
    end

    context 'guest' do
      let(:user) { nil }

      it { is_expected.to be false }
    end
  end

  describe 'cross-tenant isolation' do
    let(:tenant_platform) { create(:better_together_platform, :public) }
    let(:tenant_manager) { create(:better_together_user, :confirmed) }
    let(:tenant_role) { create(:better_together_role, :platform_role, platform: tenant_platform) }
    let(:host_role) { create(:better_together_role, :platform_role) }

    before do
      BetterTogether::AccessControlBuilder.seed_data
      permission = BetterTogether::ResourcePermission.find_by!(identifier: 'manage_platform_roles')
      manager_role = create(:better_together_role, :platform_role)
      manager_role.assign_resource_permissions([permission.identifier])
      create(:better_together_person_platform_membership, member: tenant_manager.person, joinable: tenant_platform,
                                                          role: manager_role)
    end

    it 'denies managing a role belonging to a different platform' do
      expect(described_class.new(tenant_manager, host_role).update?).to be false
      expect(described_class.new(tenant_manager, host_role).destroy?).to be false
    end

    it 'allows managing a role belonging to their own platform' do
      expect(described_class.new(tenant_manager, tenant_role).update?).to be true
    end
  end

  describe '#destroy? protected role' do
    subject { described_class.new(user, protected_role).destroy? }

    context 'platform manager' do
      let(:user) { manager_user }

      it { is_expected.to be false }
    end
  end
end
