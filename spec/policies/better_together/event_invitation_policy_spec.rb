# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EventInvitationPolicy, :as_platform_steward do
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
  let(:event) { create(:better_together_event) }
  let(:user) { find_or_create_test_user('steward@example.test', 'SecureTest123!@#', :platform_steward) }
  let(:invitation) { create(:better_together_invitation, invitable: event) }

  before do
    # Make the user an organizer of the event by adding them as an event host
    # Only apply to the default steward user, not test users without permissions
    next unless user.present? && user.respond_to?(:email) && user.email&.include?('steward@example.test')

    BetterTogether::EventHost.create!(
      event: event,
      host: user.person
    )
  end

  describe '#resend?' do
    context 'with pending event invitation' do
      let(:invitation) { create(:better_together_invitation, invitable: event, status: 'pending') }

      it 'allows resending' do
        expect(policy.resend?).to be true
      end
    end

    context 'with declined event invitation' do
      let(:invitation) { create(:better_together_invitation, invitable: event, status: 'declined') }

      it 'allows resending' do
        expect(policy.resend?).to be true
      end
    end

    context 'with accepted event invitation' do
      let(:invitation) { create(:better_together_invitation, invitable: event, status: 'accepted') }

      it 'does not allow resending' do
        expect(policy.resend?).to be false
      end
    end

    context 'when user is not an event organizer' do
      let(:user) { create(:better_together_user) }
      # Don't add user as event organizer

      it 'does not allow resending' do
        expect(policy.resend?).to be false
      end
    end
  end

  describe '#create?' do
    context 'when user is an event organizer' do
      it 'allows creating' do
        expect(policy.create?).to be true
      end
    end

    context 'when user is not an event organizer' do
      let(:user) { create(:better_together_user) }
      # Don't add user as event organizer

      it 'does not allow creating' do
        expect(policy.create?).to be false
      end
    end

    context 'when user only has broad platform management' do
      let(:user) { create(:better_together_user) }

      before do
        grant_platform_permission(user, 'manage_platform')
      end

      it 'does not allow creating without event organizer authority' do
        expect(policy.create?).to be false
      end
    end
  end

  describe '#destroy?' do
    context 'with pending event invitation' do
      let(:invitation) { create(:better_together_invitation, invitable: event, status: 'pending') }

      it 'allows destroying' do
        expect(policy.destroy?).to be true
      end
    end

    context 'with accepted event invitation' do
      let(:invitation) { create(:better_together_invitation, invitable: event, status: 'accepted') }

      it 'does not allow destroying' do
        expect(policy.destroy?).to be false
      end
    end
  end
end
