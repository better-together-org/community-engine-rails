# frozen_string_literal: true

module BetterTogether
  # Notifies attendees when an event is approaching
  class EventReminderNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message do |config|
      config.if = -> { should_notify? }
    end
    deliver_by :email, mailer: 'BetterTogether::EventMailer', method: :event_reminder, params: :email_params do |config|
      config.if = -> { recipient_has_email? && should_notify? }
    end

    param :event, :reminder_type

    notification_methods do
      delegate :event, :reminder_type, to: :event
    end

    def event = params[:event]
    def reminder_type = params[:reminder_type] || '24_hours'

    def title
      I18n.t('better_together.notifications.event_reminder.title',
             event_name: event.name,
             default: 'Reminder: %<event_name>s')
    end

    def body
      case reminder_type
      when '24_hours'
        body_24_hours
      when '1_hour'
        body_1_hour
      else
        body_generic
      end
    end

    def build_message(_notification)
      { title:, body: }
    end

    def email_params(_notification)
      { event:, reminder_type: }
    end

    private

    def body_24_hours
      I18n.t('better_together.notifications.event_reminder.body_24h',
             event_name: event.name,
             starts_at: formatted_start_time,
             default: '%<event_name>s starts tomorrow at %<starts_at>s')
    end

    def body_1_hour
      I18n.t('better_together.notifications.event_reminder.body_1h',
             event_name: event.name,
             starts_at: formatted_start_time,
             default: '%<event_name>s starts in 1 hour at %<starts_at>s')
    end

    def body_generic
      I18n.t('better_together.notifications.event_reminder.body_generic',
             event_name: event.name,
             starts_at: formatted_start_time,
             default: 'Reminder: %<event_name>s starts at %<starts_at>s')
    end

    def formatted_start_time
      I18n.l(event.starts_at, format: :long)
    end

    notification_methods do
      def recipient_has_email?
        recipient.respond_to?(:email) && recipient.email.present? &&
          (!recipient.respond_to?(:notification_preferences) ||
           recipient.notification_preferences.fetch('notify_by_email', true))
      end

      def should_notify?
        event.present? && event.starts_at.present? &&
          (!recipient.respond_to?(:notification_preferences) ||
           recipient.notification_preferences.fetch('event_reminders', true))
      end
    end
  end
end
