# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::UserPolicy do
  def grant_platform_permission(user, permission_identifier)
    BetterTogether::AccessControlBuilder.seed_data

    host_platform = BetterTogether::Platform.find_by(host: true) ||
                    create(:better_together_platform, :host, community: user.person.community)
    role = create(:better_together_role, :platform_role)
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)
    role.assign_resource_permissions([permission.identifier])
    host_platform.person_platform_memberships.find_or_create_by!(member: user.person, role:)
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
end
