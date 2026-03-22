# frozen_string_literal: true

module BetterTogether
  # Scans upcoming events and schedules per-event reminders via
  # BetterTogether::EventReminderSchedulerJob. This job is intended to be run
  # periodically by the scheduler (sidekiq-scheduler / sidekiq-cron).
  class EventReminderScanJob < ApplicationJob
    queue_as :notifications

    # Keep lightweight: find events starting in the near future and enqueue the
    # existing per-event scheduler job which handles cancellation/rescheduling.
    # @param window_hours [Integer] how far ahead to scan (default: 7 days)
    # @param platform_id [String, nil] restrict scan to one platform (nil = all platforms)
    def perform(window_hours: 168, platform_id: nil)
      cutoff = Time.current + window_hours.hours

      scope = BetterTogether::Event.where('starts_at <= ? AND starts_at >= ?', cutoff, Time.current)
      scope = scope.where(platform_id: platform_id) if platform_id.present?

      scope.find_each do |event|
        # Use the id to avoid serializing AR objects into the job payload
        BetterTogether::EventReminderSchedulerJob.perform_later(event.id)
      rescue StandardError => e
        Rails.logger.error "Failed to enqueue reminder scheduler for event #{event&.id}: #{e.message}"
      end
    end
  end
end
