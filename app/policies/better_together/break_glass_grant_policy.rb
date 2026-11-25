# frozen_string_literal: true

module BetterTogether
  # Break-glass grants are visible to the people they concern and to holders of the sealed disclosure
  # permission. Stewards and managers get nothing from platform roles: operating is not disclosing.
  class BreakGlassGrantPolicy < ApplicationPolicy
    def index?
      sealed_holder?
    end

    def show?
      return false unless agent && record.is_a?(BreakGlassGrant)

      [record.requested_by_id, record.grantee_id].include?(agent.id) || sealed_holder?
    end

    def create?
      sealed_holder?
    end

    def revoke?
      show? && !record.revoked?
    end

    def update?
      false
    end

    def destroy?
      false
    end

    # Sealed holders see the current platform's grants; everyone else sees only grants that name them.
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless agent

        sealed_holder? ? scope.where(platform_id: Current.platform.id) : own_grants
      end

      private

      def own_grants
        scope.where(requested_by_id: agent.id).or(scope.where(grantee_id: agent.id))
      end

      def sealed_holder?
        Current.platform.present? && agent.permitted_to?(BreakGlass::Request::PERMISSION, Current.platform)
      end
    end

    private

    def sealed_holder?
      agent.present? && agent.permitted_to?(BreakGlass::Request::PERMISSION, platform_for_check)
    end

    def platform_for_check
      (record.platform if record.respond_to?(:platform)) || Current.platform
    end
  end
end
