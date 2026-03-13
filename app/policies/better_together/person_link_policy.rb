# frozen_string_literal: true

module BetterTogether
  # Access control for person-to-person platform links.
  class PersonLinkPolicy < ApplicationPolicy
    def index?
      user.present? && agent.present?
    end

    def show?
      user.present? && participant?
    end

    def revoke?
      user.present? && source_participant?
    end

    # Pundit scope for PersonLink visibility.
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless agent

        scope.where(source_person_id: agent.id).or(scope.where(target_person_id: agent.id))
      end
    end

    private

    def participant?
      record.source_person_id == agent.id || record.target_person_id == agent.id
    end

    def source_participant?
      record.source_person_id == agent.id
    end
  end
end
