# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::UserPolicy do
  # rubocop:disable Metrics/AbcSize
  def grant_platform_permission(user, permission_identifier)
    BetterTogether::AccessControlBuilder.seed_data

    host_platform = BetterTogether::Platform.find_by(host: true) ||
                    create(:better_together_platform, :host, community: user.person.community)
    membership = host_platform.person_platform_memberships.find_or_initialize_by(member: user.person)
    membership.role ||= create(:better_together_role, :platform_role)
    role = membership.role
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)
    role.assign_resource_permissions([permission.identifier])
    membership.status = :active
    membership.save!
    user.person.touch
  end
  # rubocop:enable Metrics/AbcSize

  def grant_user_admin_on(user, platform)
    BetterTogether::AccessControlBuilder.seed_data
    membership = platform.person_platform_memberships.find_or_initialize_by(member: user.person)
    membership.role ||= create(:better_together_role, :platform_role)
    permission = BetterTogether::ResourcePermission.find_by!(identifier: 'manage_platform_users')
    membership.role.assign_resource_permissions([permission.identifier])
    membership.status = :active
    membership.save!
    user.person.touch
  end

  let(:platform_manager) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:user_admin) { create(:better_together_user, :confirmed) }
  let(:target_user) { create(:better_together_user, :confirmed) }

  before do
    grant_platform_permission(user_admin, 'manage_platform_users')
  end

  it 'allows users to view themselves' do
    expect(described_class.new(target_user, target_user).show?).to be true
  end

  it 'denies default platform managers from viewing other user accounts' do
    expect(described_class.new(platform_manager, target_user).show?).to be false
  end

  it 'permits explicit user-account admins to view other user accounts' do
    expect(described_class.new(user_admin, target_user).show?).to be true
  end

  it 'scopes default platform managers to their own account' do
    scope = described_class::Scope.new(platform_manager, BetterTogether::User).resolve

    expect(scope).to contain_exactly(platform_manager)
  end

  it 'scopes explicit user-account admins to all users' do
    scope = described_class::Scope.new(user_admin, BetterTogether::User).resolve

    expect(scope).to include(user_admin, target_user, platform_manager)
  end

  describe 'cross-tenant isolation' do
    let(:platform_a) { create(:better_together_platform) }
    let(:platform_b) { create(:better_together_platform) }
    let(:platform_b_user) { create(:better_together_user, :confirmed, platform: platform_b) }

    it 'denies a manage_platform_users holder on platform A from viewing a platform B user' do
      admin_a = create(:better_together_user, :confirmed)
      grant_user_admin_on(admin_a, platform_a)

      expect(described_class.new(admin_a, platform_b_user).show?).to be false
    end

    it 'allows a manage_platform_users holder on platform B to view a platform B user' do
      admin_b = create(:better_together_user, :confirmed)
      grant_user_admin_on(admin_b, platform_b)

      expect(described_class.new(admin_b, platform_b_user).show?).to be true
    end
  end
end
