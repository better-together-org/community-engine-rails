# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe EventInvitation do
    let(:event) { create(:better_together_event) }
    let(:inviter) { create(:better_together_person) }
    let(:invitee_person) { create(:better_together_person) }
    let(:invitee_email) { 'test@example.com' }

    describe 'validations' do
      context 'when inviting an existing person' do
        subject(:invitation) do
          create(:better_together_event_invitation,
                 :with_invitee,
                 invitable: event,
                 inviter: inviter)
        end

        it { is_expected.to be_valid }

        it 'prevents duplicate person invitations' do
          invitation.save!
          duplicate = build(:better_together_event_invitation,
                            :with_invitee,
                            invitable: event,
                            inviter: inviter,
                            invitee: invitation.invitee)
          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:invitee]).to include('has already been invited to this event')
        end
      end

      context 'when inviting by email' do
        subject(:invitation) do
          build(:better_together_event_invitation,
                invitable: event,
                inviter: inviter,
                invitee: nil,
                invitee_email: invitee_email)
        end

        it { is_expected.to be_valid }

        it 'prevents duplicate email invitations' do
          invitation.save!
          duplicate = build(:better_together_event_invitation,
                            invitable: event,
                            inviter: inviter,
                            invitee_email: invitee_email)
          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:invitee_email]).to include('has already been invited to this event')
        end
      end

      context 'when both invitee and invitee_email are blank' do
        subject(:invitation) do
          build(:better_together_event_invitation,
                invitable: event,
                inviter: inviter,
                invitee: nil,
                invitee_email: nil)
        end

        it { is_expected.not_to be_valid }

        it 'has the correct error message' do
          invitation.valid?
          expect(invitation.errors[:base]).to include('Either invitee or invitee_email must be present')
        end
      end
    end

    describe 'invitation types' do
      context 'with person invitation' do
        subject(:invitation) do
          build(:better_together_event_invitation,
                :with_invitee,
                invitable: event,
                inviter: inviter)
        end

        it 'identifies as person invitation' do
          expect(invitation.for_existing_user?).to be true
          expect(invitation.for_email?).to be false
          expect(invitation.invitation_type).to eq :person
        end
      end

      context 'with email invitation' do
        subject(:invitation) do
          build(:better_together_event_invitation,
                invitable: event,
                inviter: inviter,
                invitee: nil,
                invitee_email: invitee_email)
        end

        it 'identifies as email invitation' do
          expect(invitation.for_existing_user?).to be false
          expect(invitation.for_email?).to be true
          expect(invitation.invitation_type).to eq :email
        end
      end
    end

    describe 'scopes' do
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
               invitee_email: invitee_email)
      end

      describe '.for_existing_users' do
        it 'returns only person invitations' do
          expect(described_class.for_existing_users).to include(person_invitation)
          expect(described_class.for_existing_users).not_to include(email_invitation)
        end
      end

      describe '.for_email_addresses' do
        it 'returns only email invitations' do
          expect(described_class.for_email_addresses).to include(email_invitation)
          expect(described_class.for_email_addresses).not_to include(person_invitation)
        end
      end
    end

    describe '#after_accept!' do
      let(:community) { configure_host_platform&.community }
      let(:community_role) { BetterTogether::Role.find_by(identifier: 'community_member') }

      context 'with person invitation' do
        subject(:invitation) do
          create(:better_together_event_invitation,
                 :with_invitee,
                 invitable: event,
                 inviter: inviter)
        end

        it 'creates event attendance' do
          expect { invitation.after_accept!(invitee_person: invitee_person) }
            .to change(EventAttendance, :count).by(1)

          attendance = EventAttendance.last
          expect(attendance.person).to eq(invitee_person)
          expect(attendance.event).to eq(event)
          expect(attendance.status).to eq('going')
        end
      end
    end
  end
end
