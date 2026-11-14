# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformInvitationPolicy, type: :policy do
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

  let(:platform) do
    BetterTogether::AccessControlBuilder.seed_data
    BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host)
  end
  let(:invitation) { create(:better_together_platform_invitation, invitable: platform) }
  let(:member_manager) { create(:better_together_user) }
  let(:manage_only_user) { create(:better_together_user) }

  before do
    grant_platform_permission(member_manager, 'manage_platform_members')
    grant_platform_permission(manage_only_user, 'manage_platform')
  end

  it 'permits explicit platform member management' do
    expect(described_class.new(member_manager, invitation).index?).to be(true)
    expect(described_class.new(member_manager, invitation).create?).to be(true)
  end

  it 'does not treat broad platform management as invitation authority' do
    expect(described_class.new(manage_only_user, invitation).index?).to be(false)
    expect(described_class.new(manage_only_user, invitation).create?).to be(false)
  end

  it 'does not return invitations for users without explicit member-management scope' do
    resolved = described_class::Scope.new(manage_only_user, BetterTogether::PlatformInvitation).resolve

    expect(resolved).to be_empty
  end

  describe 'cross-tenant isolation' do
    let(:tenant_platform) { create(:better_together_platform, :public) }
    let(:tenant_manager) { create(:better_together_user, :confirmed) }

    before do
      role = create(:better_together_role, :platform_role)
      permission = BetterTogether::ResourcePermission.find_by!(identifier: 'manage_platform_members')
      role.assign_resource_permissions([permission.identifier])
      create(:better_together_person_platform_membership, member: tenant_manager.person, joinable: tenant_platform,
                                                          role:)
    end

    it "denies managing another platform's invitations" do
      policy = described_class.new(tenant_manager, invitation)

      expect(policy.index?).to be(false)
      expect(policy.destroy?).to be(false)
      expect(policy.resend?).to be(false)
    end

    it "excludes another platform's invitations from the resolved scope" do
      resolved = described_class::Scope.new(tenant_manager, BetterTogether::PlatformInvitation).resolve

      expect(resolved).not_to include(invitation)
    end
  end
end
