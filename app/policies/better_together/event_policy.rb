# frozen_string_literal: true

module BetterTogether
  # Access control for calendars
  class EventPolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      record.privacy_public? || creator_or_manager
    end

    alias ics? show?

    def update?
      creator_or_manager
    end

    def create?
      permitted_to?('manage_platform')
    end

    def destroy?
      creator_or_manager
    end

    # Filtering and sorting for calendars according to permissions and context
    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.order(:starts_at, created_at: :desc).where(permitted_query)
      end

      protected

      def permitted_query
        events_table = ::BetterTogether::Event.arel_table

        # Only list events that are public and where the current person is a member or a creator
        query = events_table[:privacy].eq('public')

        if permitted_to?('manage_platform')
          query = query.or(events_table[:privacy].eq('private'))
        elsif agent
          query = query.or(
            events_table[:creator_id].eq(agent.id)
          )
        end

        query
      end
    end

    protected

    def creator_or_manager
      user.present? && (record.creator == agent || permitted_to?('manage_platform'))
    end
  end
end
