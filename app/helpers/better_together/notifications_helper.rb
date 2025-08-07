# frozen_string_literal: true

module BetterTogether
  # groups view logic related to notifications
  module NotificationsHelper
    def unread_notifications?
      unread_notification_count.positive?
    end

    def unread_notification_counter
      count = unread_notification_count
      return if count.zero?

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
  end
end
