# frozen_string_literal: true

module BetterTogether
  # Base class for invitation mailers that provides common functionality
  # for sending invitation emails across different invitation types
  class InvitationMailerBase < ApplicationMailer
    # Template method pattern - subclasses implement these methods
    def invite
      invitation = params[:invitation]
      setup_invitation_data(invitation)

      to_email = invitation&.invitee_email.to_s
      return if to_email.blank?

      send_invitation_email(invitation, to_email)
    end

    protected

    # Template method to be implemented by subclasses
    def setup_invitation_data(invitation)
      @invitation = invitation
      @invitable = invitation&.invitable
      @invitation_url = invitation&.url_for_review

      # Set instance variable for specific invitable type
      instance_variable_set(invitable_instance_variable, @invitable)
    end

    def send_invitation_email(invitation, to_email)
      # Use the invitation's locale for proper internationalization
      I18n.with_locale(invitation&.locale) do
        mail(to: to_email,
             subject: invitation_subject)
      end
    end

    private

    # Template methods to be implemented by subclasses
    def invitation_subject
      raise NotImplementedError, "#{self.class} must implement #invitation_subject"
    end

    def invitable_instance_variable
      raise NotImplementedError, "#{self.class} must implement #invitable_instance_variable"
    end
  end
end
