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

    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless agent

        scope.where(
          'creator_id = :pid OR (seedable_type = :stype AND seedable_id = :pid)',
          pid: agent.id, stype: agent.class.name
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
