# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform Privacy with Event Invitations' do
  include FactoryBot::Syntax::Methods

  let(:locale) { I18n.default_locale }
  let!(:platform) { configure_host_platform }
  let!(:manager_user) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let!(:regular_user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }

  let!(:private_event) do
    create(:better_together_event,
           name: 'Private Platform Event',
           starts_at: 1.week.from_now,
           privacy: 'private',
           creator: manager_user.person)
  end

  let!(:public_event) do
    create(:better_together_event,
           name: 'Public Event',
           starts_at: 1.week.from_now,
           privacy: 'public',
           creator: manager_user.person)
  end

  # Default to private event for most tests
  let!(:event) { private_event }

  let!(:invitation) do
    create(:better_together_event_invitation,
           invitable: event,
           inviter: manager_user.person,
           invitee_email: 'external@example.test',
           status: 'pending',
           locale: I18n.default_locale)
  end

  before do
    # Make platform private to test invitation access
    platform.update!(privacy: 'private')
  end

  describe 'accessing private platform via event invitation token' do
    context 'when platform is private and user is not authenticated' do
      before do
        # Explicitly ensure no user is authenticated for this context
        reset_session if respond_to?(:reset_session)
        if respond_to?(:logout)
          begin
            logout
          rescue StandardError
            # Ignore logout errors
          end
        end
      end

      it 'allows access to event via invitation token' do
        # Direct access to event without token should redirect to login
        get better_together.event_path(event.slug, locale: locale)
        expect(response).to redirect_to(new_user_session_path(locale: locale))

        # Access with invitation token should work
        get better_together.event_path(event.slug, locale: locale, invitation_token: invitation.token)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(event.name)
      end

      it 'stores invitation token in session for later use' do
        get better_together.event_path(event.slug, locale: locale, invitation_token: invitation.token)

        # Check that token is stored in session (we can't directly access session in request specs,
        # but we can verify the functionality by checking subsequent requests work)
        expect(response).to have_http_status(:ok)

        # Subsequent requests within the same session should work without token
        get better_together.event_path(event.slug, locale: locale)
        expect(response).to have_http_status(:ok)
      end

      it 'redirects to login for expired invitation tokens' do
        # Create expired invitation using factory
        expired_invitation = create(:better_together_event_invitation, :expired,
                                    invitable: event,
                                    inviter: manager_user.person,
                                    invitee_email: 'expired@example.test')

        get better_together.event_path(event.slug, locale: locale, invitation_token: expired_invitation.token)
        expect(response).to redirect_to(new_user_session_path(locale: locale))
      end
    end

    context 'when platform is private and user is authenticated', :as_user do
      it 'allows authenticated users to access events normally' do
        get better_together.event_path(public_event.slug, locale: locale)
        expect(response).to have_http_status(:ok)
      end

      it 'still processes invitation tokens for authenticated users' do
        get better_together.event_path(public_event.slug, locale: locale, invitation_token: invitation.token)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(public_event.name)
      end
    end

    context 'when platform is public' do
      before do
        platform.update!(privacy: 'public')
      end

      it 'allows unauthenticated access to public events regardless of invitation tokens' do
        get better_together.event_path(public_event.slug, locale: locale)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(public_event.name)
      end

      it 'still processes invitation tokens on public platforms for private events' do
        get better_together.event_path(event.slug, locale: locale, invitation_token: invitation.token)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(event.name)
      end
    end
  end

  describe 'event invitation URL generation' do
    it 'generates URLs with invitation tokens that link directly to events' do
      invitation_url = invitation.url_for_review
      uri = URI.parse(invitation_url)

      expect(invitation_url).to include(event.slug)
      expect(uri.query).to include("invitation_token=#{invitation.token}")

      # Locale may be included in the path; accept either form
      if uri.query&.include?('locale=')
        expect(uri.query).to include("locale=#{invitation.locale}")
      else
        expect(uri.path).to match("/#{invitation.locale}/")
      end
    end

    it 'generated URLs bypass platform privacy restrictions' do
      invitation_url = invitation.url_for_review
      uri = URI.parse(invitation_url)
      path_with_params = "#{uri.path}?#{uri.query}"

      get path_with_params
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(event.name)
    end
  end

  describe 'registration with event invitation tokens' do
    it 'redirects to event after successful registration via invitation' do
      # Simulate visiting event with invitation token first
      get better_together.event_path(event.slug, locale: locale, invitation_token: invitation.token)
      expect(response).to have_http_status(:ok)

      # Then try to register
      post user_registration_path(locale: locale), params: {
        user: {
          email: invitation.invitee_email,
          password: 'SecureTest123!@#',
          password_confirmation: 'SecureTest123!@#',
          person_attributes: {
            name: 'New User',
            identifier: 'newuser'
          }
        },
        privacy_policy_agreement: '1',
        terms_of_service_agreement: '1',
        code_of_conduct_agreement: '1'
      }

      expect(response).to have_http_status(:ok)

      created_user = BetterTogether::User.find_by(email: invitation.invitee_email)
      created_user.confirm

      login(invitation.invitee_email, 'SecureTest123!@#')

      # Should redirect to the event after successful registration. Compare by slug to avoid locale path differences
      expect(response.request.fullpath).to include(event.slug)
    end
  end

  describe 'invitation token session management' do
    it 'clears expired invitation tokens from session' do
      # Set up session with expired invitation using factory
      expired_invitation = create(:better_together_event_invitation, :expired,
                                  invitable: event,
                                  inviter: manager_user.person,
                                  invitee_email: 'expired@example.test')

      # Try to access with expired token
      get better_together.event_path(event.slug, locale: locale, invitation_token: expired_invitation.token)
      expect(response).to redirect_to(new_user_session_path(locale: locale))

      # Subsequent access should also fail (session should be cleaned)
      get better_together.event_path(event.slug, locale: locale)
      expect(response).to redirect_to(new_user_session_path(locale: locale))
    end
  end
end
