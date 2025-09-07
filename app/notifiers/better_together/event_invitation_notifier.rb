# frozen_string_literal: true

module BetterTogether
  class EventInvitationNotifier < ApplicationNotifier # rubocop:todo Style/Documentation
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications
    deliver_by :email, mailer: 'BetterTogether::EventInvitationsMailer', method: :invite, params: :email_params,
                       queue: :mailers

    required_param :invitation

    notification_methods do
      delegate :title, :body, :invitation, :invitable, to: :event
    end

    def invitation = params[:invitation]
    def invitable = params[:invitable] || invitation&.invitable

    def title
      I18n.with_locale(params[:invitation].locale) do
        I18n.t('better_together.notifications.event_invitation.title',
               event_name: invitable&.name, default: 'You have been invited to an event')
      end
    end

    def body
      I18n.with_locale(params[:invitation].locale) do
        I18n.t('better_together.notifications.event_invitation.body',
               event_name: invitable&.name, default: 'Invitation to %<event_name>s')
      end
    end

    def build_message(_notification)
      # Pass the invitable (event) as the notification url object so views can
      # link to the event record (consistent with other notifiers that pass
      # domain objects like agreement/request).
      { title:, body:, url: invitation.url_for_review }
    end

    def email_params(_notification)
      # Include the invitation and the invitable (event) so mailers and views
      # have the full context without needing to resolve the invitation.
      { invitation: params[:invitation], invitable: }
    end
  end
end
