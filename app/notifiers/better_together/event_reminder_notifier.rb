# frozen_string_literal: true

module BetterTogether
  # Notifies attendees when an event is approaching
  class EventReminderNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications do |config|
      config.if = -> { should_notify? }
    end
    deliver_by :email, mailer: 'BetterTogether::EventMailer', method: :event_reminder, params: :email_params,
                       queue: :mailers do |config|
      config.wait = 15.minutes
      config.if = -> { send_email_notification? }
    end

    validates :record, presence: true
    required_param :reminder_type

    def event
      record
    end

    def reminder_type
      params[:reminder_type] || '24_hours'
    end

    def identifier
      event.id
    end

    def url
      ::BetterTogether::Engine.routes.url_helpers.event_url(event, locale: I18n.locale)
    end

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

    def build_message(notification)
      {
        title:,
        body:,
        identifier:,
        url:,
        unread_count: notification.recipient.notifications.unread.count
      }
    end

    def email_params(_notification)
      {
        event: event,
        person: recipient,
        reminder_type: reminder_type
      }
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
      delegate :event, to: :event
      delegate :url, to: :event
      delegate :identifier, to: :event
      delegate :reminder_type, to: :event

      def send_email_notification?
        recipient.email.present? && recipient.notify_by_email && should_send_email?
      end

      def should_notify?
        event.present? && event.starts_at.present? &&
          (!recipient.respond_to?(:notification_preferences) ||
           recipient.notification_preferences.fetch('event_reminders', true))
      end

      def should_send_email?
        # Check for unread notifications for the recipient for the record's event
        unread_notifications = recipient.notifications.where(
          event_id: BetterTogether::EventReminderNotifier.where(params: { event_id: event.id }).select(:id),
          read_at: nil
        ).order(created_at: :desc)

        if unread_notifications.none?
          false
        else
          # Only send one email per unread notifications per event
          event.id == unread_notifications.last.event.record_id
        end
      end
    end
  end
end
