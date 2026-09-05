# frozen_string_literal: true

module BetterTogether
  # Access control for linked seed records synced to a person.
  class PersonLinkedSeedPolicy < ApplicationPolicy
    def index?
      user.present? && agent.present? && feature_enabled?('person_linked_seeds')
    end

    def show?
      user.present? && record.viewable_by?(agent) && feature_enabled?('person_linked_seeds')
    end

    # Pundit scope for PersonLinkedSeed visibility.
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless agent
        return scope.none unless feature_enabled?('person_linked_seeds')

        scope.visible_to(agent)
      end
    end
  end
end
