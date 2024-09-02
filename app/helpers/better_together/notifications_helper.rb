# frozen_string_literal: true

module BetterTogether
  module NotificationsHelper
    def unread_notification_count
      count = current_person.notifications.unread.size
      return if count.zero?

      content_tag(:span, count, class: 'badge bg-primary rounded-pill position-absolute notification-badge')
    end
  end
end
