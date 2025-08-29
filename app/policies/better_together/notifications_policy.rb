# frozen_string_literal: true

module BetterTogether
  # Authorization rules for notifications actions
  class NotificationsPolicy < ApplicationPolicy
    def index?
      user.present?
    end

    def mark_as_read?
      user.present?
    end

    def mark_notification_as_read?
      mark_as_read?
    end

    def mark_record_notification_as_read?
      mark_as_read?
    end

    class Scope < ApplicationPolicy::Scope
    end
  end
end
