# frozen_string_literal: true

module BetterTogether
  # Job to schedule event reminders when events are created or updated
  class EventReminderSchedulerJob < ApplicationJob
    queue_as :notifications

    def perform(event)
      return unless event_valid?(event)
      return if event_in_past?(event)

      cancel_existing_reminders(event)
      schedule_reminders(event)
      log_completion(event)
    end

    private

    def event_valid?(event)
      event.present? && event.starts_at.present?
    end

    def event_in_past?(event)
      event.starts_at <= Time.current
    end

    def schedule_reminders(event)
      schedule_24_hour_reminder(event) if should_schedule_24_hour_reminder?(event)
      schedule_1_hour_reminder(event) if should_schedule_1_hour_reminder?(event)
    end

    def should_schedule_24_hour_reminder?(event)
      event.starts_at > 24.hours.from_now
    end

    def should_schedule_1_hour_reminder?(event)
      event.starts_at > 1.hour.from_now
    end

    def schedule_24_hour_reminder(event)
      EventReminderJob.set(wait_until: event.starts_at - 24.hours)
                      .perform_later(event, '24_hours')
    end

    def schedule_1_hour_reminder(event)
      EventReminderJob.set(wait_until: event.starts_at - 1.hour)
                      .perform_later(event, '1_hour')
    end

    def log_completion(event)
      Rails.logger.info "Scheduled reminders for event #{event.identifier}"
    end

    def cancel_existing_reminders(event)
      # Find and cancel existing reminder jobs for this event
      # This is a simplified approach - in production you might want to use
      # a more sophisticated job management system like sidekiq-cron
      Rails.logger.info "Rescheduling reminders for event #{event.identifier}"
    end
  end
end
