# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Event Invitation Token Processing' do
  let(:locale) { I18n.default_locale }
  let!(:platform) do
    existing = configure_host_platform
    if existing
      existing.update!(privacy: 'public') unless existing.privacy == 'public'
      existing
    end
  end
  let!(:manager_user) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }

  let!(:event) do
    BetterTogether::Event.create!(
      name: 'Test Event',
      starts_at: 1.week.from_now,
      identifier: SecureRandom.uuid,
      privacy: 'public',
      creator: manager_user.person
    )
  end

  let!(:invitation) do
    BetterTogether::EventInvitation.create!(
      invitable: event,
      inviter: manager_user.person,
      invitee_email: 'test@example.test',
      status: 'pending',
      locale: 'es', # Test locale handling
      token: SecureRandom.hex(16),
      valid_from: Time.zone.now,
      valid_until: 7.days.from_now
    )
  end

  describe 'EventsController invitation token processing' do
    it 'processes invitation_token parameter' do
      get better_together.event_path(event.slug, locale: locale, invitation_token: invitation.token)

      expect(response).to have_http_status(:ok)
      expect_html_content(event.name) # Use HTML assertion helper
    end

    it 'sets locale from invitation when token is processed' do
      # Make request with invitation token that has Spanish locale
      get better_together.event_path(event.slug, locale: locale, invitation_token: invitation.token)

      expect(response).to have_http_status(:ok)
      # The locale should be set to the invitation's locale (Spanish)
      expect(I18n.locale.to_s).to eq('es')
    end

    it 'handles invalid invitation tokens gracefully' do
      get better_together.event_path(event.slug, locale: locale, invitation_token: 'invalid-token')

      expect(response).to have_http_status(:ok) # Should still show event, just without invitation processing
      expect_html_content(event.name) # Use HTML assertion helper
    end

    it 'handles missing invitation tokens gracefully' do
      get better_together.event_path(event.slug, locale: locale)

      expect(response).to have_http_status(:ok)
      expect_html_content(event.name) # Use HTML assertion helper
    end

    it 'processes expired invitations correctly' do
      expired_invitation = BetterTogether::EventInvitation.create!(
        invitable: event,
        inviter: manager_user.person,
        invitee_email: 'expired@example.test',
        status: 'pending',
        locale: I18n.default_locale,
        token: SecureRandom.hex(16),
        valid_from: 2.days.ago,
        valid_until: 1.day.ago
      )

      get better_together.event_path(event.slug, locale: locale, invitation_token: expired_invitation.token)

      expect(response).to have_http_status(:ok) # Should still show event
      expect_html_content(event.name) # Use HTML assertion helper
    end
  end

  describe 'ApplicationController set_event_invitation method' do
    it 'supports both token and invitation_token parameters' do
      # Test with 'token' parameter
      get better_together.event_path(event.slug, locale: locale, token: invitation.token)
      expect(response).to have_http_status(:ok)

      # Test with 'invitation_token' parameter
      get better_together.event_path(event.slug, locale: locale, invitation_token: invitation.token)
      expect(response).to have_http_status(:ok)
    end

    it 'stores invitation token in session with expiration' do
      # We can't directly test session storage in request specs, but we can test
      # that the functionality works by ensuring subsequent requests work
      get better_together.event_path(event.slug, locale: locale, invitation_token: invitation.token)
      expect(response).to have_http_status(:ok)
    end

    it 'sets invitation locale correctly' do
      # Test that the locale is set from the invitation
      get better_together.event_path(event.slug, locale: locale, invitation_token: invitation.token)

      expect(response).to have_http_status(:ok)
      expect(I18n.locale.to_s).to eq(invitation.locale)
    end
  end

  describe 'valid_event_invitation_token_present? helper' do
    context 'with valid invitation token in session', :skip_host_setup do
      it 'returns true for valid tokens' do
        # Since we can't directly manipulate session in request specs,
        # we test this indirectly through the platform privacy check
        platform.update!(privacy: 'private')

        get better_together.event_path(event.slug, locale: locale, invitation_token: invitation.token)
        expect(response).to have_http_status(:ok) # Should work due to valid token
      end
    end

    context 'with expired invitation token in session' do
      it 'returns false and cleans up session for expired tokens' do
        expired_invitation = BetterTogether::EventInvitation.create!(
          invitable: event,
          inviter: manager_user.person,
          invitee_email: 'expired@example.test',
          status: 'pending',
          locale: I18n.default_locale,
          token: SecureRandom.hex(16),
          valid_from: 2.days.ago,
          valid_until: 1.day.ago
        )

        platform.update!(privacy: 'private')

        get better_together.event_path(event.slug, locale: locale, invitation_token: expired_invitation.token)
        expect(response).to redirect_to(new_user_session_path(locale: locale))
      end
    end

    context 'with invalid invitation token in session', :skip_host_setup do
      it 'returns false for non-existent tokens' do
        platform.update!(privacy: 'private')

        get better_together.event_path(event.slug, locale: locale, invitation_token: 'non-existent-token')
        # Invalid tokens on private platforms should render 404
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'invitation URL generation and access' do
    it 'generates correct invitation URLs' do
      invitation_url = invitation.url_for_review
      uri = URI.parse(invitation_url)

      # Token should still be present in query params
      expect(uri.query).to include("invitation_token=#{invitation.token}")

      # Locale may be embedded in the path (e.g. /es/events/...) depending on routing.
      # Accept either query param or locale segment in path.
      if uri.query&.include?('locale=')
        expect(uri.query).to include("locale=#{invitation.locale}")
      else
        expect(uri.path).to match("/#{invitation.locale}/")
      end
      expect(invitation_url).to include(event.slug)
    end

    it 'allows access via generated invitation URLs' do
      invitation_url = invitation.url_for_review
      uri = URI.parse(invitation_url)

      # Request using the path+query to preserve any path-based locale segment
      get "#{uri.path}?#{uri.query}"
      expect(response).to have_http_status(:ok)
      expect_html_content(event.name) # Use HTML assertion helper
    end

    it 'sets correct locale when accessing via invitation URL' do
      invitation_url = invitation.url_for_review
      uri = URI.parse(invitation_url)

      get "#{uri.path}?#{uri.query}"
      expect(response).to have_http_status(:ok)

      # Locale may be set via path segment; ensure effective locale equals invitation locale
      expect(I18n.locale.to_s).to eq(invitation.locale)
    end
  end

  describe 'multiple invitation tokens' do
    let!(:other_invitation) do
      BetterTogether::EventInvitation.create!(
        invitable: event,
        inviter: manager_user.person,
        invitee_email: 'other@example.test',
        status: 'pending',
        locale: 'fr',
        token: SecureRandom.hex(16),
        valid_from: Time.zone.now,
        valid_until: 7.days.from_now
      )
    end

    it 'handles switching between different invitation tokens' do
      # Access with first invitation
      get better_together.event_path(event.slug, locale: locale, invitation_token: invitation.token)
      expect(response).to have_http_status(:ok)
      # Normalize locale string encoding to avoid encoding mismatches
      expect(I18n.locale.to_s.force_encoding('UTF-8')).to eq('es')

      # Access with second invitation (different locale)
      get better_together.event_path(event.slug, locale: locale, invitation_token: other_invitation.token)
      expect(response).to have_http_status(:ok)
      expect(I18n.locale.to_s).to eq('fr')
    end

    it 'maintains the most recent invitation token in session' do
      # Access with first invitation
      get better_together.event_path(event.slug, locale: locale, invitation_token: invitation.token)
      expect(response).to have_http_status(:ok)

      # Access with second invitation
      get better_together.event_path(event.slug, locale: locale, invitation_token: other_invitation.token)
      expect(response).to have_http_status(:ok)

      # Subsequent access should use the latest invitation context
      get better_together.event_path(event.slug, locale: locale)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'invitation token parameter precedence' do
    it 'prioritizes invitation_token over token parameter' do
      other_invitation = BetterTogether::EventInvitation.create!(
        invitable: event,
        inviter: manager_user.person,
        invitee_email: 'priority@example.test',
        status: 'pending',
        locale: 'fr',
        token: SecureRandom.hex(16),
        valid_from: Time.zone.now,
        valid_until: 7.days.from_now
      )

      # Pass both parameters, invitation_token should take precedence
      get better_together.event_path(event.slug, locale: locale,
                                                 token: invitation.token,
                                                 invitation_token: other_invitation.token)

      expect(response).to have_http_status(:ok)
      expect(I18n.locale.to_s).to eq('fr') # Should use other_invitation's locale
    end
  end
end
