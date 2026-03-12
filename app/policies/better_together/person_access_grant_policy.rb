# frozen_string_literal: true

module BetterTogether
  class PersonAccessGrantPolicy < ApplicationPolicy
    def index?
      user.present? && agent.present?
    end

    def show?
      user.present? && participant?
    end

    def update?
      user.present? && grantor?
    end

    def revoke?
      update?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless agent

        scope.where(
          scope.arel_table[:grantor_person_id].eq(agent.id)
          .or(scope.arel_table[:grantee_person_id].eq(agent.id))
        )
      end
    end

    private

    def participant?
      record.grantor_person_id == agent.id || record.grantee_person_id == agent.id
    end

    def grantor?
      record.grantor_person_id == agent.id
    end
  end
end
