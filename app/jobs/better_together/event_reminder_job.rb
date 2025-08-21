# frozen_string_literal: true

module BetterTogether
  # Job to send event reminders to attendees
  class EventReminderJob < ApplicationJob
    queue_as :notifications

    retry_on StandardError, wait: :polynomially_longer, attempts: 5
    discard_on ActiveRecord::RecordNotFound

    def perform(event_or_id, reminder_type = '24_hours')
      event = find_event(event_or_id)
      return unless event_valid?(event)

      attendees = going_attendees(event)
      send_reminders_to_attendees(event, attendees, reminder_type)
      log_completion(event, attendees, reminder_type)
    end

    private

    def find_event(event_or_id)
      return event_or_id if event_or_id.is_a?(BetterTogether::Event)

      BetterTogether::Event.find(event_or_id) if event_or_id.present?
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def event_valid?(event)
      event.present? && event.starts_at.present?
    end

    def going_attendees(event)
      # Get people who have 'going' status for this event
      person_ids = event.event_attendances.where(status: 'going').pluck(:person_id)
      BetterTogether::Person.where(id: person_ids)
    end

    def send_reminders_to_attendees(event, attendees, reminder_type)
      attendees.find_each do |attendee|
        send_reminder_to_attendee(event, attendee, reminder_type)
      end
    end

    def send_reminder_to_attendee(event, attendee, reminder_type)
      BetterTogether::EventReminderNotifier.with(
        record: event,
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
