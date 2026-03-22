# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EventInvitationPolicy, :as_platform_manager do
  subject(:policy) { described_class.new(user, invitation) }

  let(:community) { create(:better_together_community) }
  let(:event) { create(:better_together_event) }
  let(:user) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:invitation) { create(:better_together_invitation, invitable: event) }

  before do
    # Make the user an organizer of the event by adding them as an event host
    # Only apply to the default manager user, not test users without permissions
    next unless user.present? && user.respond_to?(:email) && user.email&.include?('manager@example.test')

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
