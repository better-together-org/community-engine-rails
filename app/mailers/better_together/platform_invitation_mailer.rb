# app/mailers/better_together/platform_invitation_mailer.rb

module BetterTogether
  class PlatformInvitationMailer < ApplicationMailer
    def invite(platform_invitation)
      @platform_invitation = platform_invitation
      @platform = platform_invitation.invitable

      Time.use_zone(@platform.time_zone) do
        @invitee_email = @platform_invitation.invitee_email
        @valid_from = @platform_invitation.valid_from
        @valid_until = @platform_invitation.valid_until

        # @invitation_url = better_together.accept_platform_invitation_url(token: @platform_invitation.token)
        @invitation_url = '#'

        I18n.with_locale(@platform_invitation.locale) do
          mail(to: @invitee_email, subject: I18n.t('better_together.platform_invitation_mailer.invite.subject', platform: @platform.name))
        end
      end
    end
  end
end
