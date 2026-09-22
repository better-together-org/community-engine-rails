# frozen_string_literal: true

module BetterTogether
  # Access control for person-to-person access grants.
  class PersonAccessGrantPolicy < ApplicationPolicy
    def index?
      user.present? && agent.present? && feature_enabled?('person_access_grants')
    end

    def show?
      user.present? && participant? && feature_enabled?('person_access_grants')
    end

    def update?
      user.present? && grantor? && feature_enabled?('person_access_grants')
    end

    def revoke?
      update?
    end

    # Pundit scope for PersonAccessGrant visibility.
    # Scoped to the current platform's connections so grants are only visible within
    # the federation context where they were issued.
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless agent
        return scope.none unless feature_enabled?('person_access_grants')

        person_scope = participant_scope
        return person_scope unless current_platform

        person_scope.for_platform(current_platform)
      end

      private

      def participant_scope
        scope.where(grantor_person_id: agent.id)
             .or(scope.where(grantee_person_id: agent.id))
      end

      def current_platform
        Current.platform || Current.host_platform
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
