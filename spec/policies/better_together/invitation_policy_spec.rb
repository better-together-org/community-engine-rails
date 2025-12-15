# frozen_string_literal: true

require 'rails_helper'

# Testing CommunityInvitationPolicy as a concrete implementation of InvitationPolicy
# InvitationPolicy is an abstract base class with template methods
# rubocop:disable RSpec/NestedGroups, RSpec/SpecFilePathFormat
RSpec.describe BetterTogether::CommunityInvitationPolicy, :as_platform_manager do
  subject(:policy) { described_class.new(user, invitation) }

  let(:user) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#') }
  let(:community) { create(:better_together_community) }
  let(:invitation) { create(:better_together_community_invitation, invitable: community) }

  before do
    # Grant the user community management permissions via PersonCommunityMembership
    next unless user.present? # Skip setup for nil user tests

    coordinator_role = BetterTogether::Role.find_by(identifier: 'community_coordinator')
    BetterTogether::PersonCommunityMembership.create!(
      joinable: community,
      member: user.person,
      role: coordinator_role
    )
  end

  describe '#resend?' do
    context 'when user is present and has permission' do
      context 'with pending invitation' do
        let(:invitation) { create(:better_together_community_invitation, invitable: community, status: 'pending') }

        it 'allows resending' do
          expect(policy.resend?).to be true
        end
      end

      context 'with declined invitation' do
        let(:invitation) { create(:better_together_community_invitation, invitable: community, status: 'declined') }

        it 'allows resending' do
          expect(policy.resend?).to be true
        end
      end

      context 'with accepted invitation' do
        let(:invitation) { create(:better_together_community_invitation, invitable: community, status: 'accepted') }

        it 'does not allow resending' do
          expect(policy.resend?).to be false
        end
      end
    end

    context 'when user is not present' do
      let(:user) { nil }

      it 'does not allow resending' do
        expect(policy.resend?).to be false
      end
    end

    context 'when user does not have permission' do
      let(:unprivileged_user) { create(:better_together_user) }
      let(:policy) { described_class.new(unprivileged_user, invitation) }

      # Don't add user as community member

      it 'does not allow resending' do
        expect(policy.resend?).to be false
      end
    end
  end

  describe '#create?' do
    context 'when user is present and has permission on invitable' do
      it 'allows creating' do
        expect(policy.create?).to be true
      end
    end

    context 'when user is not present' do
      let(:user) { nil }

      it 'does not allow creating' do
        expect(policy.create?).to be false
      end
    end

    context 'when user does not have permission' do
      let(:unprivileged_user) { create(:better_together_user) }
      let(:policy) { described_class.new(unprivileged_user, invitation) }

      # Don't add user as community member

      it 'does not allow creating' do
        expect(policy.create?).to be false
      end
    end
  end

  describe '#destroy?' do
    context 'when user is present and has permission' do
      context 'with pending invitation' do
        let(:invitation) { create(:better_together_community_invitation, invitable: community, status: 'pending') }

        it 'allows destroying' do
          expect(policy.destroy?).to be true
        end
      end

      context 'with accepted invitation' do
        let(:invitation) { create(:better_together_community_invitation, invitable: community, status: 'accepted') }

        it 'does not allow destroying' do
          expect(policy.destroy?).to be false
        end
      end
    end

    context 'when user is not present' do
      let(:user) { nil }

      it 'does not allow destroying' do
        expect(policy.destroy?).to be false
      end
    end

    context 'when user does not have permission' do
      let(:unprivileged_user) { create(:better_together_user) }
      let(:policy) { described_class.new(unprivileged_user, invitation) }

      # Don't add user as community member

      it 'does not allow destroying' do
        expect(policy.destroy?).to be false
      end
    end
  end
end
# rubocop:enable RSpec/NestedGroups, RSpec/SpecFilePathFormat
