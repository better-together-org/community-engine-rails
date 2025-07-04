# frozen_string_literal: true

module BetterTogether
  # groups view logic related to notifications
  module NotificationsHelper
    def unread_notification_count
      count = current_person.notifications.unread.size
      return if count.zero?

      content_tag(:span, count, class: 'badge bg-primary rounded-pill position-absolute notification-badge', id: 'person_notification_count')
    end

    def recent_notifications
      current_person.notifications.joins(:event).order(created_at: :desc).limit(5)
    end
  end
end
