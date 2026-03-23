# frozen_string_literal: true

module BetterTogether
  # Pundit policy scoping seeds to the authenticated person (GDPR self-service access)
  class PersonSeedPolicy < ApplicationPolicy
    def index?
      agent.present?
    end

    def show?
      owns_seed?
    end

    def export?
      agent.present?
    end

    def destroy?
      owns_seed?
    end

    # Resolves seeds owned by or seeded from the authenticated agent.
    class Scope < ApplicationPolicy::Scope
      def resolve # rubocop:todo Metrics/AbcSize
        return scope.none unless agent

        t = scope.arel_table
        scope.where(
          t[:creator_id].eq(agent.id).or(
            t[:seedable_type].eq(agent.class.name).and(t[:seedable_id].eq(agent.id))
          )
        ).latest_first
      end
    end

    private

    def owns_seed?
      agent.present? && (
        record.creator_id == agent.id ||
        (record.seedable_type == agent.class.name && record.seedable_id == agent.id)
      )
    end
  end
end
