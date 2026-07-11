# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ResourcePermissionPolicy, type: :policy do
  def grant_platform_permission(user, permission_identifier)
    BetterTogether::AccessControlBuilder.seed_data

    host_platform = BetterTogether::Platform.find_by(host: true) ||
                    create(:better_together_platform, :host, community: user.person.community)
    role = create(:better_together_role, :platform_role)
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)
    role.assign_resource_permissions([permission.identifier])
    membership = host_platform.person_platform_memberships.find_or_create_by!(member: user.person, role:)
    membership.update!(status: 'active') unless membership.active?
  end

  let(:role_manager) { create(:better_together_user) }
  let(:normal_user) { create(:better_together_user) }

  let(:platform_permission) do
    BetterTogether::AccessControlBuilder.seed_data
    BetterTogether::ResourcePermission.find_by(resource_type: 'BetterTogether::Platform') ||
      create(:better_together_resource_permission, resource_type: 'BetterTogether::Platform')
  end

  before { grant_platform_permission(role_manager, 'manage_platform_roles') }

  describe '#index?' do
    it 'denies guests' do
      expect(described_class.new(nil, BetterTogether::ResourcePermission).index?).to be false
    end

    it 'denies users without role management permission' do
      expect(described_class.new(normal_user, BetterTogether::ResourcePermission).index?).to be false
    end

    it 'allows users with manage_platform_roles' do
      expect(described_class.new(role_manager, BetterTogether::ResourcePermission).index?).to be true
    end
  end

  describe '#show?' do
    it 'denies guests' do
      expect(described_class.new(nil, platform_permission).show?).to be false
    end

    it 'denies users without role management permission' do
      expect(described_class.new(normal_user, platform_permission).show?).to be false
    end

    it 'allows users with manage_platform_roles for platform-type permissions' do
      expect(described_class.new(role_manager, platform_permission).show?).to be true
    end
  end

  describe '#destroy?' do
    it 'allows role managers to destroy unprotected permissions' do
      permission = platform_permission
      allow(permission).to receive(:protected?).and_return(false)
      expect(described_class.new(role_manager, permission).destroy?).to be true
    end

    it 'blocks destruction of protected permissions even for role managers' do
      permission = platform_permission
      allow(permission).to receive(:protected?).and_return(true)
      expect(described_class.new(role_manager, permission).destroy?).to be false
    end
  end
end
