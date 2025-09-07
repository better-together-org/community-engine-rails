# frozen_string_literal: true

module BetterTogether
  class EventInvitationNotifier < ApplicationNotifier # rubocop:todo Style/Documentation
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications
    deliver_by :email, mailer: 'BetterTogether::EventInvitationsMailer', method: :invite, params: :email_params,
                       queue: :mailers

    required_param :invitation

    def event
      params[:invitation].invitable
    end

    def title
      I18n.with_locale(params[:invitation].locale) do
        I18n.t('better_together.notifications.event_invitation.title',
               event_name: event&.name, default: 'You have been invited to an event')
      end
    end

    def body
      I18n.with_locale(params[:invitation].locale) do
        I18n.t('better_together.notifications.event_invitation.body',
               event_name: event&.name, default: 'Invitation to %<event_name>s')
      end
    end

    def build_message(_notification)
      { title:, body:, url: params[:invitation].url_for_review }
    end

    def email_params(_notification)
      params[:invitation]
    end
  end
end
