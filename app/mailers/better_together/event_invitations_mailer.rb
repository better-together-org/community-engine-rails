# frozen_string_literal: true

module BetterTogether
  class EventInvitationsMailer < ApplicationMailer
    def invite(invitation)
      @invitation = invitation
      @event = invitation.invitable
      @invitation_url = invitation.url_for_review

      to_email = invitation[:invitee_email].to_s
      return if to_email.blank?

      mail(to: to_email,
           subject: I18n.t('better_together.event_invitations_mailer.invite.subject',
                           default: 'You are invited to an event'))
    end
  end
end
