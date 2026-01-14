# frozen_string_literal: true

module BetterTogether
  # groups view logic related to notifications
  module NotificationsHelper
    def unread_notifications?
      count = unread_notification_count
      count&.positive?
    end

    def unread_notification_counter
      count = unread_notification_count
      return if count.nil? || count.zero?

      content_tag(:span, count, class: 'badge bg-primary rounded-pill position-absolute notification-badge',
                                id: 'person_notification_count')
    end

    def unread_notification_count
      return unless current_person

      current_person.notifications.unread.size
    end

    def recent_notifications
      current_person.notifications.joins(:event).order(created_at: :desc).limit(5)
    end

    # Fragment cache key for notification types
    def notification_fragment_cache_key(notification)
      # Base cache key with notification's cache_key_with_version
      base_key = [notification.cache_key_with_version]

      # Add related record version if it exists and has cache_key_with_version
      if notification.event&.record.respond_to?(:cache_key_with_version)
        base_key << notification.event.record.cache_key_with_version
      end

      # Add event cache key for consistency
      base_key << notification.event.cache_key_with_version if notification.event.respond_to?(:cache_key_with_version)

      # Add locale for i18n support
      base_key << I18n.locale

      base_key
    end

    # Type-specific fragment cache key for notification patterns
    def notification_type_fragment_cache_key(notification)
      type_key = [
        notification.type || notification.class.name,
        notification.cache_key_with_version,
        I18n.locale
      ]

      # Add related record cache key if available
      if notification.event&.record.respond_to?(:cache_key_with_version)
        type_key << notification.event.record.cache_key_with_version
      end

      type_key
    end

    # Cache expiration utilities for notifications
    def expire_notification_fragments(notification)
      # Expire all fragments related to this notification
      expire_fragment(notification_fragment_cache_key(notification))
      expire_fragment(notification_type_fragment_cache_key(notification))

      # Expire header/content/footer fragments
      expire_fragment(['notification_header', notification.cache_key_with_version])
      expire_fragment(['notification_content', notification.cache_key_with_version])
      expire_fragment(['notification_footer', notification.cache_key_with_version])
    end

    # Expire fragments for a specific notification type pattern
    def expire_notification_type_fragments(notification_type)
      # This is useful when you want to expire all cached fragments for a specific notification type
      # Note: This requires more specific cache management based on your needs
      Rails.cache.delete_matched("*#{notification_type}*")
    end

    # Check if a notification should use fragment caching
    def should_cache_notification?(notification)
      # Only cache if the notification and its record are present and have cache keys
      notification.present? &&
        notification.event&.record.present? &&
        notification.respond_to?(:cache_key_with_version)
    end
  end
end
