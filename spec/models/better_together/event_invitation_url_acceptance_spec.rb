# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EventInvitation do
  let(:event) { create(:better_together_event) }
  let(:inviter) { create(:better_together_person) }

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

      if uri.query&.include?('locale=')
        expect(uri.query).to include('locale=es')
      else
        expect(uri.path).to match('/es/')
      end

      expect(url).not_to include('/invitations/')
    end

    it 'includes proper locale in generated URLs' do
      url = invitation.url_for_review
      uri = URI.parse(url)

      params = uri.query ? CGI.parse(uri.query) : {}

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
             invitee: create(:better_together_person),
             status: 'pending')
    end

    describe '#after_accept!' do
      it 'creates event attendance with going status' do
        expect do
          invitation.after_accept!(invitee_person: invitation.invitee)
        end.to change(BetterTogether::EventAttendance, :count).by(1)

        attendance = BetterTogether::EventAttendance.last
        expect(attendance.person).to eq(invitation.invitee)
        expect(attendance.event).to eq(event)
        expect(attendance.status).to eq('going')
      end

      it 'does not create duplicate community memberships' do
        community = configure_host_platform&.community
        community.person_community_memberships.create!(
          member: invitation.invitee,
          role: BetterTogether::Role.find_by(identifier: 'community_member')
        )

        expect do
          invitation.after_accept!(invitee_person: invitation.invitee)
        end.not_to change(community.person_community_memberships, :count)
      end

      it 'handles missing community gracefully' do
        allow(event.creator).to receive(:primary_community).and_return(nil)

        expect do
          invitation.after_accept!(invitee_person: invitation.invitee)
        end.to change(BetterTogether::EventAttendance, :count).by(1)

        attendance = BetterTogether::EventAttendance.last
        expect(attendance.person).to eq(invitation.invitee)
      end

      it 'handles missing event creator gracefully' do
        allow(event).to receive(:creator).and_return(nil)

        expect do
          invitation.after_accept!(invitee_person: invitation.invitee)
        end.to change(BetterTogether::EventAttendance, :count).by(1)
      end
    end

    describe '#accept!' do
      it 'sets status to accepted and calls after_accept!' do
        expect(invitation).to receive(:after_accept!).with(invitee_person: invitation.invitee)

        invitation.accept!(invitee_person: invitation.invitee)

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
end
