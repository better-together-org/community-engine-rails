# frozen_string_literal: true

module BetterTogether
  # Mixin for sync state tracking on PlatformConnection.
  module PlatformConnectionSyncTracking
    extend ActiveSupport::Concern

    def sync_idle?
      last_sync_status == 'idle'
    end

    def sync_running?
      last_sync_status == 'running'
    end

    def sync_succeeded?
      last_sync_status == 'succeeded'
    end

    def sync_failed?
      last_sync_status == 'failed'
    end

    def sync_healthy?
      !sync_failed?
    end

    def last_sync_started_at_time
      parse_time_value(last_sync_started_at)
    end

    def last_synced_at_time
      parse_time_value(last_synced_at)
    end

    def last_sync_error_at_time
      parse_time_value(last_sync_error_at)
    end

    def mark_sync_started!(cursor: nil, started_at: Time.current)
      update!(
        sync_cursor: normalized_cursor(cursor),
        last_sync_status: 'running',
        last_sync_started_at: started_at.iso8601,
        last_sync_error_at: '',
        last_sync_error_message: ''
      )
      record_sync_activity('platform_connection.sync_started')
    end

    def mark_sync_succeeded!(cursor: nil, item_count: 0, synced_at: Time.current, message: nil)
      update!(
        sync_cursor: normalized_cursor(cursor),
        last_sync_status: 'succeeded',
        last_synced_at: synced_at.iso8601,
        last_sync_error_at: '',
        last_sync_error_message: message.to_s.truncate(500),
        last_sync_item_count: item_count.to_i
      )
      record_sync_activity('platform_connection.sync_succeeded', parameters: { item_count: item_count.to_i })
    end

    def mark_sync_failed!(message:, cursor: nil, failed_at: Time.current)
      update!(
        sync_cursor: normalized_cursor(cursor),
        last_sync_status: 'failed',
        last_sync_error_at: failed_at.iso8601,
        last_sync_error_message: message.to_s.truncate(500)
      )
      record_sync_activity('platform_connection.sync_failed', parameters: { message: message.to_s.truncate(500) })
    end

    private

    # PlatformConnection deliberately does not include TrackedActivity/PublicActivity::Model
    # (it has no privacy column, and connection audit activity must never leak into the
    # public ActivityPolicy::Scope-filtered feed) — so activities are recorded directly
    # rather than through the trackable.create_activity convenience method. Consumers
    # (FederationHub::ActivityFeedService) query BetterTogether::Activity for these records
    # directly, gating visibility via controller-level permission checks instead.
    def record_sync_activity(key, parameters: {})
      ::BetterTogether::Activity.create!(trackable: self, key:, parameters:)
    end

    def normalized_cursor(value)
      value.to_s
    end

    def parse_time_value(value)
      return if value.blank?

      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end
  end
end
