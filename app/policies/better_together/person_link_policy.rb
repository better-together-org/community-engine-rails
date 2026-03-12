# frozen_string_literal: true

module BetterTogether
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

    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless agent

        scope.where(
          scope.arel_table[:source_person_id].eq(agent.id)
          .or(scope.arel_table[:target_person_id].eq(agent.id))
        )
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
