# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::CommunityInvitationPolicy, :as_platform_steward do
  subject(:policy) { described_class.new(user, invitation) }

  def grant_platform_permission(user, permission_identifier)
    BetterTogether::AccessControlBuilder.seed_data

    host_platform = BetterTogether::Platform.find_by(host: true) ||
                    create(:better_together_platform, :host, community: user.person.community)
    role = create(:better_together_role, :platform_role)
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)
    role.assign_resource_permissions([permission.identifier])
    host_platform.person_platform_memberships.find_or_create_by!(member: user.person, role:)
  end

  let(:community) { create(:better_together_community) }
  let(:user) { find_or_create_test_user('steward@example.test', 'SecureTest123!@#', :platform_steward) }
  let(:invitation) { create(:better_together_invitation, invitable: community) }

  before do
    # Grant the user community management permissions via PersonCommunityMembership
    # Only apply to the default steward user, not test users without permissions
    next unless user.respond_to?(:person) && user.email&.include?('steward@example.test')

    coordinator_role = BetterTogether::Role.find_by(identifier: 'community_organizer') ||
                       BetterTogether::Role.find_by(identifier: 'community_coordinator')
    BetterTogether::PersonCommunityMembership.create!(
      joinable: community,
      member: user.person,
      role: coordinator_role
    )
  end

  describe '#resend?' do
    context 'with pending community invitation' do
      let(:invitation) { create(:better_together_invitation, invitable: community, status: 'pending') }

      it 'allows resending' do
        expect(policy.resend?).to be true
      end
    end

    context 'with declined community invitation' do
      let(:invitation) { create(:better_together_invitation, invitable: community, status: 'declined') }

      it 'allows resending' do
        expect(policy.resend?).to be true
      end
    end

    context 'with accepted community invitation' do
      let(:invitation) { create(:better_together_invitation, invitable: community, status: 'accepted') }

      it 'does not allow resending' do
        expect(policy.resend?).to be false
      end
    end

    context 'when user does not have permission on community' do
      let(:user) { create(:better_together_user) }
      # Don't add user as community member

      it 'does not allow resending' do
        expect(policy.resend?).to be false
      end
    end
  end

  describe '#create?' do
    context 'when user has community management permission' do
      it 'allows creating' do
        expect(policy.create?).to be true
      end
    end

    context 'when user does not have permission on community' do
      let(:user) { create(:better_together_user) }
      # Don't add user as community member

      it 'does not allow creating' do
        expect(policy.create?).to be false
      end
    end

    context 'when user only has broad platform management' do
      let(:user) { create(:better_together_user) }

      before do
        grant_platform_permission(user, 'manage_platform')
      end

      it 'does not allow creating without explicit community invitation authority' do
        expect(policy.create?).to be false
      end
    end
  end

  describe '#destroy?' do
    context 'with pending community invitation' do
      let(:invitation) { create(:better_together_invitation, invitable: community, status: 'pending') }

      it 'allows destroying' do
        expect(policy.destroy?).to be true
      end
    end

    context 'with accepted community invitation' do
      let(:invitation) { create(:better_together_invitation, invitable: community, status: 'accepted') }

      it 'does not allow destroying' do
        expect(policy.destroy?).to be false
      end
    end
  end
end
