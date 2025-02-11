# frozen_string_literal: true

# app/mailers/better_together/platform_invitation_mailer.rb

module BetterTogether
  # Sends the email to the recipient to accept or decline their invitation to the platform
  class PlatformInvitationMailer < ApplicationMailer
    def invite(platform_invitation)
      @platform_invitation = platform_invitation
      @platform = platform_invitation.invitable

      # Override time zone and locale if necessary
      self.locale = platform_invitation.locale

      @invitee_email = @platform_invitation.invitee_email
      @valid_from = @platform_invitation.valid_from
      @valid_until = @platform_invitation.valid_until

      @invitation_url = better_together.new_user_registration_url(invitation_code: @platform_invitation.token)

      mail(to: @invitee_email,
           subject: I18n.t('better_together.platform_invitation_mailer.invite.subject',
                           platform: @platform.name))
    end
  end
end
