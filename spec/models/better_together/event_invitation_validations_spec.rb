# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EventInvitation do
  let(:event) { create(:better_together_event) }
  let(:inviter) { create(:better_together_person) }
  let(:invitee_person) { create(:better_together_person) }

  describe 'enhanced validations' do
    context 'invitation uniqueness' do
      it 'prevents duplicate person invitations for the same event' do
        create(:better_together_event_invitation,
               invitable: event,
               inviter: inviter,
               invitee: invitee_person,
               status: 'pending')

        duplicate = build(:better_together_event_invitation,
                          invitable: event,
                          inviter: inviter,
                          invitee: invitee_person,
                          status: 'pending')

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:invitee]).to include('has already been invited to this event')
      end

      it 'prevents duplicate email invitations for the same event' do
        email = 'test@example.com'

        create(:better_together_event_invitation,
               invitable: event,
               inviter: inviter,
               invitee_email: email,
               status: 'pending')

        duplicate = build(:better_together_event_invitation,
                          invitable: event,
                          inviter: inviter,
                          invitee_email: email,
                          status: 'pending')

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:invitee_email]).to include('has already been taken')
      end

      it 'allows duplicate invitations if previous one was declined' do
        create(:better_together_event_invitation,
               invitable: event,
               inviter: inviter,
               invitee: invitee_person,
               status: 'declined')

        new_invitation = build(:better_together_event_invitation,
                               invitable: event,
                               inviter: inviter,
                               invitee: invitee_person,
                               status: 'pending')

        expect(new_invitation).to be_valid
      end

      it 'allows same person to be invited to different events' do
        other_event = create(:better_together_event)

        create(:better_together_event_invitation,
               invitable: event,
               inviter: inviter,
               invitee: invitee_person,
               status: 'pending')

        other_invitation = build(:better_together_event_invitation,
                                 invitable: other_event,
                                 inviter: inviter,
                                 invitee: invitee_person,
                                 status: 'pending')

        expect(other_invitation).to be_valid
      end
    end

    context 'invitee presence validation' do
      it 'requires either invitee or invitee_email' do
        invitation = build(:better_together_event_invitation,
                           invitable: event,
                           inviter: inviter,
                           invitee: nil,
                           invitee_email: nil)

        expect(invitation).not_to be_valid
        expect(invitation.errors[:base]).to include('must have either an invitee or invitee email')
      end

      it 'accepts invitation with invitee only' do
        invitation = build(:better_together_event_invitation,
                           invitable: event,
                           inviter: inviter,
                           invitee: invitee_person,
                           invitee_email: nil)

        expect(invitation).to be_valid
      end

      it 'accepts invitation with invitee_email only' do
        invitation = build(:better_together_event_invitation,
                           invitable: event,
                           inviter: inviter,
                           invitee: nil,
                           invitee_email: 'test@example.com')

        expect(invitation).to be_valid
      end
    end
  end
end
