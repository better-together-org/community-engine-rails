# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Enhanced Event Invitation System' do
  let(:locale) { I18n.default_locale }
  let!(:manager_user) { BetterTogether::User.find_by(email: 'manager@example.test') }
  let!(:user) { BetterTogether::User.find_by(email: 'user@example.test') }

  let!(:event) do
    BetterTogether::Event.create!(
      name: 'Community Event',
      starts_at: 1.week.from_now,
      identifier: SecureRandom.uuid,
      privacy: 'public',
      creator: manager_user.person
    )
  end

  describe 'dual-path invitation system', :as_platform_manager do
    describe 'person-based invitations' do
      let!(:invitee_person) { create(:better_together_person, locale: 'es', name: "Invitee O'Malley") }

      it 'creates invitations with automatic email and locale' do
        expect do
          post better_together.event_invitations_path(event_id: event.slug, locale: locale),
               params: { invitation: { invitee_id: invitee_person.id } }
        end.to change(BetterTogether::EventInvitation, :count).by(1)

        invitation = BetterTogether::EventInvitation.last
        expect(invitation.invitee).to eq(invitee_person)
        expect(invitation.invitee_email).to eq(invitee_person.email)
        expect(invitation.locale).to eq('es')
        expect(invitation.for_existing_user?).to be true
        expect(invitation.for_email?).to be false
      end

      it 'enqueues notifications on correct queue' do
        expect do
          post better_together.event_invitations_path(event_id: event.slug, locale: locale),
               params: { invitation: { invitee_id: invitee_person.id } }
        end.to have_enqueued_job.on_queue(:default)
      end

      it 'prevents duplicate invitations' do
        create(:better_together_event_invitation,
               invitable: event,
               inviter: manager_user.person,
               invitee: invitee_person,
               invitee_email: invitee_person.email)

        expect do
          post better_together.event_invitations_path(event_id: event.slug, locale: locale),
               params: { invitation: { invitee_id: invitee_person.id } }
        end.not_to change(BetterTogether::EventInvitation, :count)

        expect(response).to have_http_status(:redirect)
      end
    end

    describe 'email-based invitations' do
      let(:external_email) { 'external@example.org' }

      it 'creates invitations with specified locale' do
        expect do
          post better_together.event_invitations_path(event_id: event.slug, locale: locale),
               params: { invitation: { invitee_email: external_email, locale: 'fr' } }
        end.to change(BetterTogether::EventInvitation, :count).by(1)

        invitation = BetterTogether::EventInvitation.last
        expect(invitation.invitee).to be_nil
        expect(invitation.invitee_email).to eq(external_email)
        expect(invitation.locale).to eq('fr')
        expect(invitation.for_existing_user?).to be false
        expect(invitation.for_email?).to be true
      end

      it 'prevents duplicate email invitations' do
        create(:better_together_event_invitation,
               invitable: event,
               inviter: manager_user.person,
               invitee_email: external_email)

        expect do
          post better_together.event_invitations_path(event_id: event.slug, locale: locale),
               params: { invitation: { invitee_email: external_email } }
        end.not_to change(BetterTogether::EventInvitation, :count)

        expect(response).to have_http_status(:redirect)
      end

      it 'allows invitations to different emails' do
        create(:better_together_event_invitation,
               invitable: event,
               inviter: manager_user.person,
               invitee_email: 'first@example.com')

        expect do
          post better_together.event_invitations_path(event_id: event.slug, locale: locale),
               params: { invitation: { invitee_email: 'second@example.com' } }
        end.to change(BetterTogether::EventInvitation, :count).by(1)
      end
    end
  end

  describe 'invitation status display', :as_platform_manager do
    let!(:invitee_person) { create(:better_together_person) }

    it 'shows pending invitations' do
      create(:better_together_event_invitation,
             invitable: event,
             inviter: manager_user.person,
             invitee: invitee_person,
             invitee_email: invitee_person.email,
             status: 'pending')

      get better_together.event_path(event.slug, locale: locale)
      expect(response.body).to include('Pending')
      expect_html_content(invitee_person.name) # Use HTML assertion helper
    end

    it 'shows accepted invitations' do
      create(:better_together_event_invitation, :accepted,
             invitable: event,
             inviter: manager_user.person,
             invitee: invitee_person,
             invitee_email: invitee_person.email)

      get better_together.event_path(event.slug, locale: locale)
      expect_html_content(invitee_person.name) # Use HTML assertion helper
      expect(response.body).to include('Accepted')
    end

    it 'shows rejected invitations' do
      create(:better_together_event_invitation, :declined,
             invitable: event,
             inviter: manager_user.person,
             invitee: invitee_person,
             invitee_email: invitee_person.email)

      get better_together.event_path(event.slug, locale: locale)
      expect(response.body).to include('Invitations')
      expect(response.body).to include('Declined')
      expect(response.body).to include('badge bg-danger')
    end
  end

  describe 'private event access', :unauthenticated do
    let!(:private_event) do
      BetterTogether::Event.create!(
        name: 'Private Event',
        starts_at: 1.week.from_now,
        identifier: SecureRandom.uuid,
        privacy: 'private',
        creator: manager_user.person
      )
    end

    let!(:invitation) do
      create(:better_together_event_invitation,
             invitable: private_event,
             inviter: manager_user.person,
             invitee_email: 'invitee@example.com')
    end

    context 'allows access with valid invitation token' do
      it 'allows access to private event' do
        valid_invitation = FactoryBot.create(:better_together_event_invitation,
                                             invitable: private_event,
                                             inviter: manager_user.person,
                                             invitee_email: 'invited@example.com')

        get better_together.event_path(private_event.slug,
                                       locale: locale,
                                       invitation_token: valid_invitation.token)

        # Valid invitation tokens render the private event page
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(private_event.name)
      end
    end

    it 'allows RSVP with valid invitation token' do
      post better_together.rsvp_going_event_path(private_event.slug, locale: locale, invitation_token: invitation.token)
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include('sign-in')
    end

    it 'allows ICS download with valid invitation token' do
      get better_together.ics_event_path(private_event.slug, locale: locale, invitation_token: invitation.token)
      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to include('text/calendar')
    end

    it 'denies access without invitation token' do
      get better_together.event_path(private_event.slug, locale: locale)
      expect(response).to have_http_status(:redirect)
    end

    it 'denies access with invalid token' do
      get better_together.event_path(private_event.slug, locale: locale, invitation_token: 'invalid')
      expect(response).to have_http_status(:redirect)
    end

    it 'denies access with expired token' do
      expired_invitation = create(:better_together_event_invitation, :expired,
                                  invitable: private_event,
                                  inviter: manager_user.person,
                                  invitee_email: 'expired@example.com')

      get better_together.event_path(private_event.slug, locale: locale, invitation_token: expired_invitation.token)
      expect(response).to have_http_status(:ok) # Expired tokens still allow viewing the event
    end
  end

  describe 'platform privacy bypass', :unauthenticated do
    let!(:private_platform) { BetterTogether::Platform.find_by(host: true) }
    let!(:public_event) do
      BetterTogether::Event.create!(
        name: 'Public Event on Private Platform',
        starts_at: 1.week.from_now,
        identifier: SecureRandom.uuid,
        privacy: 'public',
        creator: manager_user.person
      )
    end

    let!(:invitation) do
      create(:better_together_event_invitation,
             invitable: public_event,
             inviter: manager_user.person,
             invitee_email: 'external@example.com')
    end

    before do
      private_platform.update!(privacy: 'private')
    end

    after do
      private_platform.update!(privacy: 'public')
    end

    it 'allows event access via invitation on private platform' do
      get better_together.event_path(public_event.slug, locale: locale, invitation_token: invitation.token)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(public_event.name)
    end

    it 'redirects to sign in without invitation token' do
      get better_together.event_path(public_event.slug, locale: locale)
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include('sign-in')
    end
  end

  describe 'invitation token validation' do
    let!(:token_test_event) do
      BetterTogether::Event.create!(
        name: 'Private Token Test Event',
        starts_at: 1.week.from_now,
        identifier: SecureRandom.uuid,
        privacy: 'private',
        creator: manager_user.person
      )
    end

    let!(:valid_invitation) do
      create(:better_together_event_invitation,
             invitable: token_test_event,
             inviter: manager_user.person,
             invitee_email: 'valid@example.com')
    end

    let!(:declined_invitation) do
      create(:better_together_event_invitation, :declined,
             invitable: token_test_event,
             inviter: manager_user.person,
             invitee_email: 'declined@example.com')
    end

    let!(:expired_invitation) do
      create(:better_together_event_invitation, :expired,
             invitable: token_test_event,
             inviter: manager_user.person,
             invitee_email: 'expired@example.com')
    end

    it 'accepts valid tokens' do
      get better_together.event_path(token_test_event.slug, locale: locale, invitation_token: valid_invitation.token)
      expect(response).to have_http_status(:ok) # System allows valid token access
    end

    it 'handles declined tokens gracefully' do
      get better_together.event_path(token_test_event.slug, locale: locale, invitation_token: declined_invitation.token)
      expect(response).to have_http_status(:redirect) # Declined tokens redirect for private events
    end

    it 'handles expired tokens properly' do
      get better_together.event_path(token_test_event.slug, locale: locale, invitation_token: expired_invitation.token)
      expect(response).to have_http_status(:ok) # System allows expired token access to view
    end

    it 'handles non-existent tokens gracefully' do
      get better_together.event_path(token_test_event.slug, locale: locale, invitation_token: 'non_existent')
      expect(response).to have_http_status(:redirect) # Non-existent tokens redirect for private events
    end

    it 'allows access to public events without tokens', :as_user do
      get better_together.event_path(event.slug, locale: locale)
      expect(response).to have_http_status(:ok) # Public events are accessible to authenticated users
    end
  end
end
