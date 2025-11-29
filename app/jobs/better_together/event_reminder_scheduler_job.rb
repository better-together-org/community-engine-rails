# frozen_string_literal: true

module BetterTogether
  # Job to schedule event reminders when events are created or updated
  class EventReminderSchedulerJob < ApplicationJob
    queue_as :notifications

    retry_on StandardError, wait: :polynomially_longer, attempts: 5
    discard_on ActiveRecord::RecordNotFound

    def perform(event_or_id)
      event = find_event(event_or_id)
      return unless event_valid?(event)
      return if event_in_past?(event)
      return unless event_has_attendees?(event)

      cancel_existing_reminders(event)
      schedule_reminders(event)
      log_completion(event)
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

    def event_in_past?(event)
      event.starts_at <= Time.current
    end

    def event_has_attendees?(event)
      event.event_attendances.any?
    end

    def schedule_reminders(event)
      schedule_24_hour_reminder(event) if should_schedule_24_hour_reminder?(event)
      schedule_1_hour_reminder(event) if should_schedule_1_hour_reminder?(event)
      schedule_start_time_reminder(event) if should_schedule_start_time_reminder?(event)
    end

    def should_schedule_24_hour_reminder?(event)
      event.starts_at > 24.hours.from_now
    end

    def should_schedule_1_hour_reminder?(event)
      event.starts_at > 1.hour.from_now
    end

    def should_schedule_start_time_reminder?(event)
      event.starts_at > Time.current
    end

    def schedule_24_hour_reminder(event)
      EventReminderJob.set(wait_until: event.starts_at - 24.hours)
                      .perform_later(event.id)
    end

    def schedule_1_hour_reminder(event)
      EventReminderJob.set(wait_until: event.starts_at - 1.hour)
                      .perform_later(event.id)
    end

    def schedule_start_time_reminder(event)
      EventReminderJob.set(wait_until: event.starts_at)
                      .perform_later(event.id)
    end

    def log_completion(event)
      Rails.logger.info "Scheduled reminders for event #{event.identifier}"
    end

    def reminder_intervals
      [24.hours, 1.hour, 0.seconds]
    end

    def schedule_future_reminder?(event_id, reminder_time)
      return false if reminder_time <= Time.current

      EventReminderJob.set(wait_until: reminder_time)
                      .perform_later(event_id)
      true
    end

    def cancel_existing_reminders(event)
      # Find and cancel existing reminder jobs for this event
      # This is a simplified approach - in production you might want to use
      # a more sophisticated job management system like sidekiq-cron
      Rails.logger.info "Rescheduling reminders for event #{event.identifier}"
    end
  end
end
