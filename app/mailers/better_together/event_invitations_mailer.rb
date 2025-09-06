# frozen_string_literal: true

module BetterTogether
  class EventInvitationsMailer < ApplicationMailer # rubocop:todo Style/Documentation
    def invite(invitation)
      @invitation = invitation
      @event = invitation.invitable
      @invitation_url = invitation.url_for_review

      to_email = invitation.invitee_email.to_s
      return if to_email.blank?

      # Use the invitation's locale for proper internationalization
      I18n.with_locale(invitation.locale) do
        mail(to: to_email,
             subject: I18n.t('better_together.event_invitations_mailer.invite.subject',
                             event_name: @event&.name,
                             default: 'You are invited to %<event_name>s'))
      end
    end
  end
end
