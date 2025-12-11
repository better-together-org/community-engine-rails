# frozen_string_literal: true

module BetterTogether
  # Notifier for event invitation notifications
  # Inherits from InvitationNotifierBase for shared notification functionality
  class EventInvitationNotifier < InvitationNotifierBase
    deliver_by :email, mailer: 'BetterTogether::EventInvitationsMailer', method: :invite, params: :email_params,
                       queue: :mailers

    notification_methods do
      delegate :title, :body, :invitation, :invitable, to: :event
    end

    private

    def title_i18n_key
      'better_together.notifications.event_invitation.title'
    end

    def body_i18n_key
      'better_together.notifications.event_invitation.body'
    end

    def title_i18n_vars
      { event_name: invitable&.name }
    end

    def body_i18n_vars
      { event_name: invitable&.name }
    end

    def default_title
      'You have been invited to an event'
    end

    def default_body
      'Invitation to %<event_name>s'
    end
  end
end
