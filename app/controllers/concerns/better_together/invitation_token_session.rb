# frozen_string_literal: true

module BetterTogether
  # Module for managing invitation tokens and session storage
  # Handles storing, retrieving, and validating invitation tokens in user sessions
  module InvitationTokenSession
    extend ActiveSupport::Concern

    private

    # Store invitation token in session (unified across invitation types)
    def store_invitation_token_in_session(invitation, invitation_type)
      store_token_and_expiry_in_session(invitation, invitation_type)
      configure_locale_from_invitation(invitation)
      assign_current_invitation_token(invitation)
    end

    # Store token and expiry time in session
    def store_token_and_expiry_in_session(invitation, invitation_type)
      token_key = "#{invitation_type}_invitation_token"
      expires_key = "#{invitation_type}_invitation_expires_at"

      session[token_key] = invitation.token
      session[expires_key] = invitation_expiry_time(invitation)
    end

    # Configure locale from invitation if available
    def configure_locale_from_invitation(invitation)
      return unless invitation.locale.present?

      I18n.locale = invitation.locale
      session[:locale] = I18n.locale
    end

    # Assign current invitation token for authorization if method is available
    def assign_current_invitation_token(invitation)
      return unless respond_to?(:current_invitation_token=)

      self.current_invitation_token = invitation.token
    end

    # Determine appropriate expiry time for session storage
    def invitation_expiry_time(invitation)
      if invitation.valid_until.present?
        invitation.valid_until
      else
        BetterTogether::Invitable.default_invitation_session_duration.from_now
      end
    end

    # Clear session data for specific invitation type
    def clear_invitation_session_data(invitation_type)
      token_key = "#{invitation_type}_invitation_token"
      expires_key = "#{invitation_type}_invitation_expires_at"

      session.delete(token_key)
      session.delete(expires_key)
    end
  end
end
