# frozen_string_literal: true

module BetterTogether
  # Job to send event reminders to attendees
  class EventReminderJob < ApplicationJob
    queue_as :notifications

    def perform(event, reminder_type = '24_hours')
      return unless event_valid?(event)

      attendees = going_attendees(event)
      send_reminders_to_attendees(event, attendees, reminder_type)
      log_completion(event, attendees, reminder_type)
    end

    private

    def event_valid?(event)
      event.present? && event.starts_at.present?
    end

    def going_attendees(event)
      event.attendees.joins(:event_attendances)
           .where(better_together_event_attendances: { status: 'going' })
    end

    def send_reminders_to_attendees(event, attendees, reminder_type)
      attendees.find_each do |attendee|
        send_reminder_to_attendee(event, attendee, reminder_type)
      end
    end

    def send_reminder_to_attendee(event, attendee, reminder_type)
      BetterTogether::EventReminderNotifier.with(
        event: event,
        reminder_type: reminder_type
      ).deliver(attendee)
    rescue StandardError => e
      Rails.logger.error "Failed to send event reminder to #{attendee.identifier}: #{e.message}"
    end

    def log_completion(event, attendees, reminder_type)
      Rails.logger.info "Sent #{reminder_type} reminders for event #{event.identifier} to #{attendees.count} attendees"
    end
  end
end
