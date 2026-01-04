# frozen_string_literal: true

module BetterTogether
  # Mailer for sending event invitation emails
  # Inherits from InvitationMailerBase for shared invitation email functionality
  class EventInvitationsMailer < InvitationMailerBase
    private

    def invitation_subject
      I18n.t('better_together.event_invitations_mailer.invite.subject',
             event_name: @invitable&.name,
             default: 'You are invited to %<event_name>s')
    end

    def invitable_instance_variable
      :@event
    end
  end
end
