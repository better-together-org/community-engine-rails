# frozen_string_literal: true

module BetterTogether
  class EventInvitationNotifier < ApplicationNotifier # rubocop:todo Style/Documentation
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message
    deliver_by :email, mailer: 'BetterTogether::EventInvitationsMailer', method: :invite, params: :email_params

    param :invitation

    notification_methods do
      def invitation = params[:invitation]
      def event = invitation.invitable
    end

    def title
      I18n.t('better_together.notifications.event_invitation.title',
             event_name: event&.name, default: 'You have been invited to an event')
    end

    def body
      I18n.t('better_together.notifications.event_invitation.body',
             # rubocop:todo Lint/DuplicateHashKey
             event_name: event&.name, default: 'Invitation to %<event_name>s', event_name: event&.name)
      # rubocop:enable Lint/DuplicateHashKey
    end

    def build_message(_notification)
      { title:, body:, url: invitation.url_for_review }
    end

    def email_params(_notification)
      { invitation: }
    end
  end
end
