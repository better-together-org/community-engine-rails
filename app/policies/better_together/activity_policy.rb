# frozen_string_literal: true

module BetterTogether
  # Access control fro PublicActivity::Activity records
  class ActivityPolicy < ApplicationPolicy
    def index?
      user.present?
    end

    def show?
      user.present?
    end

    # Filter and sort public activity results
    class Scope < ApplicationPolicy::Scope
      def resolve
        # Eager load trackables and owners to prevent N+1 queries
        results = scope.includes(:trackable, :owner)
                       .order(updated_at: :desc)
                       .where.not(trackable: nil)

        # Filter by activity privacy at database level
        query = table[:privacy].eq('public')
        results = results.where(query)

        # Platform managers see all public activities regardless of trackable state
        return results if permitted_to?('manage_platform')

        # Filter by trackable visibility at instance level using each trackable's visibility API
        results.select do |activity|
          activity.trackable&.trackable_visible_in_activity_feed?(user)
        end
      end

      def table
        scope.arel_table
      end
    end
  end
end
