# frozen_string_literal: true

module BetterTogether
  # Job to schedule event reminders when events are created or updated
  class EventReminderSchedulerJob < ApplicationJob
    REMINDER_CACHE_NAMESPACE = 'better_together/event_reminders/scheduled'

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
      # Check using event's local timezone
      event.local_starts_at <= Time.current
    end

    def event_has_attendees?(event)
      event.event_attendances.any?
    end

    def schedule_reminders(event)
      schedule_future_reminder?(event, '24_hours', event.local_starts_at - 24.hours) if should_schedule_24_hour_reminder?(event)
      schedule_future_reminder?(event, '1_hour', event.local_starts_at - 1.hour) if should_schedule_1_hour_reminder?(event)
      schedule_future_reminder?(event, 'start_time', event.local_starts_at) if should_schedule_start_time_reminder?(event)
    end

    def should_schedule_24_hour_reminder?(event)
      # Use event's local time for accurate reminder scheduling
      event.local_starts_at > 24.hours.from_now
    end

    def should_schedule_1_hour_reminder?(event)
      # Use event's local time for accurate reminder scheduling
      event.local_starts_at > 1.hour.from_now
    end

    def should_schedule_start_time_reminder?(event)
      # Use event's local time for accurate reminder scheduling
      event.local_starts_at > Time.current
    end

    def log_completion(event)
      Rails.logger.info "Scheduled reminders for event #{event.identifier}"
    end

    def reminder_intervals
      [24.hours, 1.hour, 0.seconds]
    end

    def schedule_future_reminder?(event, reminder_type, reminder_time)
      return false if reminder_time <= Time.current
      return false unless remember_scheduled_reminder(event, reminder_type, reminder_time)

      EventReminderJob.set(wait_until: reminder_time)
                      .perform_later(event.id, reminder_type, reminder_time.iso8601)
      true
    end

    def cancel_existing_reminders(event)
      # Existing queued jobs may already exist for prior schedules. We rely on a
      # cache-backed scheduling key plus send-time stale checks in
      # EventReminderJob to keep reruns idempotent without queue introspection.
      Rails.logger.info "Ensuring reminder idempotency for event #{event.identifier}"
    end

    def remember_scheduled_reminder(event, reminder_type, reminder_time)
      reminder_cache.write(
        scheduled_reminder_cache_key(event, reminder_type, reminder_time),
        true,
        expires_in: scheduled_reminder_cache_ttl(event),
        unless_exist: true
      )
    end

    def scheduled_reminder_cache_key(event, reminder_type, reminder_time)
      "#{REMINDER_CACHE_NAMESPACE}/#{event.id}/#{reminder_type}/#{reminder_time.to_i}"
    end

    def scheduled_reminder_cache_ttl(event)
      ttl = event.local_starts_at - Time.current + 2.days
      ttl.positive? ? ttl : 1.hour
    end

    def reminder_cache
      @reminder_cache ||= if Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
                            ActiveSupport::Cache::MemoryStore.new
                          else
                            Rails.cache
                          end
    end
  end
end
