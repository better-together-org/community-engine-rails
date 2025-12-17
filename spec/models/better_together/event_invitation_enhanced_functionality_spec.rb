# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EventInvitation do
  let(:event) { create(:better_together_event) }
  let(:inviter) { create(:better_together_person) }
  let(:invitee_person) { create(:better_together_person, locale: 'es') }
  let(:community) { configure_host_platform&.community }
  let(:community_role) { BetterTogether::Role.find_by(identifier: 'community_member') }

  describe 'enhanced validations' do
    context 'invitation uniqueness' do
      it 'prevents duplicate person invitations for the same event' do
        # Create first invitation
        create(:better_together_event_invitation,
               invitable: event,
               inviter: inviter,
               invitee: invitee_person,
               status: 'pending')

        # Try to create duplicate
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

        # Create first invitation
        create(:better_together_event_invitation,
               invitable: event,
               inviter: inviter,
               invitee_email: email,
               status: 'pending')

        # Try to create duplicate
        duplicate = build(:better_together_event_invitation,
                          invitable: event,
                          inviter: inviter,
                          invitee_email: email,
                          status: 'pending')

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:invitee_email]).to include('has already been taken')
      end

      it 'allows duplicate invitations if previous one was declined' do
        # Create declined invitation
        create(:better_together_event_invitation,
               invitable: event,
               inviter: inviter,
               invitee: invitee_person,
               status: 'declined')

        # Should allow new invitation
        new_invitation = build(:better_together_event_invitation,
                               invitable: event,
                               inviter: inviter,
                               invitee: invitee_person,
                               status: 'pending')

        expect(new_invitation).to be_valid
      end

      it 'allows same person to be invited to different events' do
        other_event = create(:better_together_event)

        # Create invitation for first event
        create(:better_together_event_invitation,
               invitable: event,
               inviter: inviter,
               invitee: invitee_person,
               status: 'pending')

        # Should allow invitation to different event
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

  describe 'enhanced URL generation' do
    let(:invitation) do
      create(:better_together_event_invitation,
             invitable: event,
             inviter: inviter,
             invitee_email: 'test@example.com',
             locale: 'es',
             token: 'test-token-123')
    end

    it 'generates URLs that link directly to the event with invitation token' do
      url = invitation.url_for_review
      uri = URI.parse(url)

      expect(url).to include(event.slug)
      expect(uri.query).to include('invitation_token=test-token-123')

      # Locale may be embedded in the path (e.g. /es/events/...), accept either
      if uri.query&.include?('locale=')
        expect(uri.query).to include('locale=es')
      else
        expect(uri.path).to match('/es/')
      end

      expect(url).not_to include('/invitations/') # Should not use generic invitation path
    end

    it 'includes proper locale in generated URLs' do
      url = invitation.url_for_review
      uri = URI.parse(url)

      params = uri.query ? CGI.parse(uri.query) : {}

      # If locale present in query, assert it; otherwise ensure path contains locale segment
      if params['locale'].present?
        expect(params['locale']).to eq(['es'])
      else
        expect(uri.path).to match('/es/')
      end

      expect(params['invitation_token']).to eq(['test-token-123'])
    end
  end

  describe 'enhanced acceptance flow' do
    let(:invitation) do
      create(:better_together_event_invitation,
             invitable: event,
             inviter: inviter,
             invitee: invitee_person,
             status: 'pending')
    end

    describe '#after_accept!' do
      it 'creates event attendance with going status' do
        expect do
          invitation.after_accept!(invitee_person: invitee_person)
        end.to change(BetterTogether::EventAttendance, :count).by(1)

        attendance = BetterTogether::EventAttendance.last
        expect(attendance.person).to eq(invitee_person)
        expect(attendance.event).to eq(event)
        expect(attendance.status).to eq('going')
      end

      it 'does not create duplicate community memberships' do
        # Create existing membership
        community.person_community_memberships.create!(
          member: invitee_person,
          role: community_role
        )

        expect do
          invitation.after_accept!(invitee_person: invitee_person)
        end.not_to change(community.person_community_memberships, :count)
      end

      it 'handles missing community gracefully' do
        allow(event.creator).to receive(:primary_community).and_return(nil)

        expect do
          invitation.after_accept!(invitee_person: invitee_person)
        end.to change(BetterTogether::EventAttendance, :count).by(1)

        # Should still create attendance even without community
        attendance = BetterTogether::EventAttendance.last
        expect(attendance.person).to eq(invitee_person)
      end

      it 'handles missing event creator gracefully' do
        allow(event).to receive(:creator).and_return(nil)

        expect do
          invitation.after_accept!(invitee_person: invitee_person)
        end.to change(BetterTogether::EventAttendance, :count).by(1)
      end
    end

    describe '#accept!' do
      it 'sets status to accepted and calls after_accept!' do
        expect(invitation).to receive(:after_accept!).with(invitee_person: invitee_person)

        invitation.accept!(invitee_person: invitee_person)

        expect(invitation.status).to eq('accepted')
        expect(invitation).to be_persisted
      end
    end

    describe '#decline!' do
      it 'sets status to declined' do
        invitation.decline!

        expect(invitation.status).to eq('declined')
        expect(invitation).to be_persisted
      end
    end
  end

  describe 'token generation' do
    it 'automatically generates a token before validation' do
      invitation = build(:better_together_event_invitation,
                         invitable: event,
                         inviter: inviter,
                         invitee_email: 'test@example.com',
                         token: nil)

      expect(invitation.token).to be_nil
      invitation.valid?
      expect(invitation.token).to be_present
    end

    it 'does not overwrite existing tokens' do
      original_token = 'existing-token'
      invitation = build(:better_together_event_invitation,
                         invitable: event,
                         inviter: inviter,
                         invitee_email: 'test@example.com',
                         token: original_token)

      invitation.valid?
      expect(invitation.token).to eq(original_token)
    end
  end

  describe 'locale handling' do
    it 'validates locale is in available locales' do
      invitation = build(:better_together_event_invitation,
                         invitable: event,
                         inviter: inviter,
                         invitee_email: 'test@example.com',
                         locale: 'invalid')

      expect(invitation).not_to be_valid
      expect(invitation.errors[:locale]).to include('is not included in the list')
    end

    it 'accepts valid locales' do
      invitation = build(:better_together_event_invitation,
                         invitable: event,
                         inviter: inviter,
                         invitee_email: 'test@example.com',
                         locale: 'es')

      expect(invitation).to be_valid
    end

    it 'requires locale to be present' do
      invitation = build(:better_together_event_invitation,
                         invitable: event,
                         inviter: inviter,
                         invitee_email: 'test@example.com',
                         locale: nil)

      expect(invitation).not_to be_valid
      expect(invitation.errors[:locale]).to include("can't be blank")
    end
  end
end
