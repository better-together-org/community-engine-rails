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

    def group_notifications(scope)
      grouped = scope.includes(:event).group_by do |n|
        [n.event.record_type, n.event.record_id]
      end

      groups = grouped.map do |_key, notifications|
        latest = notifications.max_by(&:created_at)
        [latest, notifications.count]
      end
      groups.sort_by { |notification, _count| notification.created_at }.reverse
    end

    def recent_notifications
      group_notifications(current_person.notifications).first(5)
    end
  end
end
