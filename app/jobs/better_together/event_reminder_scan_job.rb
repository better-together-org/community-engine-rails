# frozen_string_literal: true

module BetterTogether
  # Scans upcoming events and schedules per-event reminders via
  # BetterTogether::EventReminderSchedulerJob. This job is intended to be run
  # periodically by the scheduler (sidekiq-scheduler / sidekiq-cron).
  class EventReminderScanJob < ApplicationJob
    queue_as :notifications

    # Keep lightweight: find events starting in the near future and enqueue the
    # existing per-event scheduler job which handles cancellation/rescheduling.
    # default: next 7 days
    def perform(window_hours: 168)
      cutoff = Time.current + window_hours.hours

      BetterTogether::Event.where('starts_at <= ? AND starts_at >= ?', cutoff, Time.current).find_each do |event|
        # Use the id to avoid serializing AR objects into the job payload
        BetterTogether::EventReminderSchedulerJob.perform_later(event.id)
      rescue StandardError => e
        Rails.logger.error "Failed to enqueue reminder scheduler for event #{event&.id}: #{e.message}"
      end
    end
  end
end
