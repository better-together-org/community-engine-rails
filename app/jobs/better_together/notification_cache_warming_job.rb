# frozen_string_literal: true

module BetterTogether
  # Background job for warming notification fragment caches
  class NotificationCacheWarmingJob < ApplicationJob
    queue_as :low_priority

    # @param notification_ids [Array<String>] IDs of notifications to warm
    # @param platform_id [String, nil] platform context for cache key resolution
    def perform(notification_ids, platform_id: nil)
      notifications = Noticed::Notification.where(id: notification_ids).includes(event: :record)

      with_platform_context(platform_id) do
        notifications.find_each do |notification|
          warm_notification_fragments(notification) if should_warm_cache?(notification)
        end
      end
    end

    private

    # Set Current.platform for the duration of the block so that cache keys
    # generated during render match the keys used by the live request stack.
    def with_platform_context(platform_id)
      if platform_id.present?
        ::Current.platform = BetterTogether::Platform.find_by(id: platform_id)
      end
      yield
    ensure
      ::Current.reset
    end

    def warm_notification_fragments(notification)
      # Generate cache keys without actually rendering to check existence
      fragment_key = notification_fragment_cache_key(notification)
      type_key = notification_type_fragment_cache_key(notification)

      # Only warm if not already cached
      return if Rails.cache.exist?(fragment_key) && Rails.cache.exist?(type_key)

      # Render the notification to warm the cache
      ApplicationController.renderer.render(
        partial: notification,
        locals: {},
        formats: [:html]
      )
    rescue StandardError => e
      Rails.logger.warn "Failed to warm cache for notification #{notification.id}: #{e.message}"
    end

    def should_warm_cache?(notification)
      notification.event&.record.present? &&
        notification.respond_to?(:cache_key_with_version) &&
        notification.created_at > 1.week.ago # Only warm recent notifications
    end

    def notification_fragment_cache_key(notification)
      base_key = [notification.cache_key_with_version]
      if notification.event&.record.respond_to?(:cache_key_with_version)
        base_key << notification.event.record.cache_key_with_version
      end
      base_key << notification.event.cache_key_with_version if notification.event.respond_to?(:cache_key_with_version)
      base_key << I18n.locale
      base_key
    end

    def notification_type_fragment_cache_key(notification)
      type_key = [
        notification.type || notification.class.name,
        notification.cache_key_with_version,
        I18n.locale
      ]
      if notification.event&.record.respond_to?(:cache_key_with_version)
        type_key << notification.event.record.cache_key_with_version
      end
      type_key
    end
  end
end
