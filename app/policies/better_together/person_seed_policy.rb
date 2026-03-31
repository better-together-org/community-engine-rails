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

    # Resolves personal export seeds for the authenticated agent (GDPR self-service).
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless agent

        scope.personal_exports_for(agent).latest_first
      end
    end

    private

    def owns_seed?
      agent.present? && record.personal_export? && record.seedable_id.to_s == agent.id.to_s
    end
  end
end
