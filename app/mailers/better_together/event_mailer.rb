# frozen_string_literal: true

module BetterTogether
  # Mailer for event-related notifications
  class EventMailer < ApplicationMailer
    # Sends event reminder emails
    def event_reminder(recipient, event, reminder_type = '24_hours')
      @event = event
      @reminder_type = reminder_type
      @recipient = recipient
      @platform = BetterTogether::Platform.find_by(host: true)

      mail(
        to: recipient.email,
        subject: reminder_subject(event)
      )
    end

    # Sends event update emails
    def event_update(recipient, event, changed_attributes)
      @event = event
      @changed_attributes = changed_attributes
      @recipient = recipient
      @platform = BetterTogether::Platform.find_by(host: true)

      mail(
        to: recipient.email,
        subject: update_subject(event)
      )
    end

    private

    def reminder_subject(event)
      I18n.t(
        'better_together.event_mailer.event_reminder.subject',
        event_name: event.name,
        default: 'Reminder: %<event_name>s'
      )
    end

    def update_subject(event)
      I18n.t(
        'better_together.event_mailer.event_update.subject',
        event_name: event.name,
        default: 'Event updated: %<event_name>s'
      )
    end
  end
end
