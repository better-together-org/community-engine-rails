# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EventInvitation do
  let(:event) { create(:better_together_event) }
  let(:inviter) { create(:better_together_person) }
  let(:invitee_person) { create(:better_together_person, locale: 'es') }

  describe 'invitation type helpers' do
    context 'person invitation' do
      let(:invitation) do
        build(:better_together_event_invitation,
              invitable: event,
              inviter: inviter,
              invitee: invitee_person,
              invitee_email: nil)
      end

      it 'correctly identifies as person invitation' do
        expect(invitation.invitation_type).to eq(:person)
        expect(invitation.for_existing_user?).to be true
        expect(invitation.for_email?).to be false
      end
    end

    context 'email invitation' do
      let(:invitation) do
        build(:better_together_event_invitation,
              invitable: event,
              inviter: inviter,
              invitee: nil,
              invitee_email: 'test@example.com')
      end

      it 'correctly identifies as email invitation' do
        expect(invitation.invitation_type).to eq(:email)
        expect(invitation.for_existing_user?).to be false
        expect(invitation.for_email?).to be true
      end
    end

    context 'unknown invitation type' do
      let(:invitation) do
        build(:better_together_event_invitation,
              invitable: event,
              inviter: inviter,
              invitee: nil,
              invitee_email: nil)
      end

      it 'identifies as unknown when both are nil' do
        expect(invitation.invitation_type).to eq(:unknown)
        expect(invitation.for_existing_user?).to be false
        expect(invitation.for_email?).to be false
      end
    end
  end

  describe 'enhanced scopes' do
    let!(:person_invitation) do
      create(:better_together_event_invitation,
             :with_invitee,
             invitable: event,
             inviter: inviter)
    end

    let!(:email_invitation) do
      create(:better_together_event_invitation,
             invitable: event,
             inviter: inviter,
             invitee: nil,
             invitee_email: 'email@example.com')
    end

    describe '.for_existing_users' do
      it 'returns only invitations with an invitee person' do
        results = described_class.for_existing_users

        expect(results).to include(person_invitation)
        expect(results).not_to include(email_invitation)
      end
    end

    describe '.for_email_addresses' do
      it 'returns only invitations with an email address but no invitee' do
        results = described_class.for_email_addresses

        expect(results).to include(email_invitation)
        expect(results).not_to include(person_invitation)
      end
    end
  end
end
