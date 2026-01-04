# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::CommunityInvitationPolicy, :as_platform_manager do
  subject(:policy) { described_class.new(user, invitation) }

  let(:community) { create(:better_together_community) }
  let(:user) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#') }
  let(:invitation) { create(:better_together_invitation, invitable: community) }

  before do
    # Grant the user community management permissions via PersonCommunityMembership
    # Only apply to the default manager user, not test users without permissions
    next unless user.respond_to?(:person) && user.email&.include?('manager@example.test')

    coordinator_role = BetterTogether::Role.find_by(identifier: 'community_coordinator')
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
