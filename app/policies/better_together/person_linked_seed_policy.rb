# frozen_string_literal: true

module BetterTogether
  class PersonLinkedSeedPolicy < ApplicationPolicy
    def index?
      user.present? && agent.present?
    end

    def show?
      user.present? && record.viewable_by?(agent)
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless agent

        scope.visible_to(agent)
      end
    end
  end
end
