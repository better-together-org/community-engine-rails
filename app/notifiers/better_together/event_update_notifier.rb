# frozen_string_literal: true

module BetterTogether
  # Notifies attendees when an event is updated
  class EventUpdateNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications do |config|
      config.if = -> { should_notify? }
    end
    deliver_by :email, mailer: 'BetterTogether::EventMailer', method: :event_update, params: :email_params,
                       queue: :mailers do |config|
      config.if = -> { recipient_has_email? && should_notify? }
    end

    required_param :event, :changed_attributes

    notification_methods do
      delegate :event, :changed_attributes, to: :params

      def should_notify?
        event.present? && changed_attributes.present? &&
          (!recipient.respond_to?(:notification_preferences) ||
           recipient.notification_preferences.fetch('event_updates', true))
      end
    end

    def target_event = params[:event]
    def changed_attributes = params[:changed_attributes] || []

    def title
      I18n.t('better_together.notifications.event_update.title',
             event_name: target_event.name,
             default: 'Event updated: %<event_name>s')
    end

    def body
      change_list = changed_attributes.map do |attr|
        I18n.t("better_together.notifications.event_update.changes.#{attr}", default: attr.humanize)
      end.join(', ')

      I18n.t('better_together.notifications.event_update.body',
             event_name: target_event.name,
             changes: change_list,
             default: '%<event_name>s has been updated: %<changes>s')
    end

    def build_message(notification)
      I18n.with_locale(locale_for_notification(notification)) do
        { title:, body: }
      end
    end

    def email_params(_notification)
      { event: target_event, changed_attributes: }
    end
  end
end
