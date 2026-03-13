# frozen_string_literal: true

module BetterTogether
  # Access control for person-to-person access grants.
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

    # Pundit scope for PersonAccessGrant visibility.
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless agent

        scope.where(grantor_person_id: agent.id).or(scope.where(grantee_person_id: agent.id))
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
