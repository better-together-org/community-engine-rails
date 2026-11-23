# frozen_string_literal: true

module BetterTogether
  # Managed-platform stewards decide: accept, narrow, suspend, resume and revoke. Operator stewards may read
  # their edges and request new ones. Every check passes the platform record, never a bare permitted_to?.
  class PlatformManagementPolicy < PlatformRecordPolicy
    def index?
      agent.present?
    end

    def show?
      managed_steward? || operator_steward?
    end

    def create?
      record.requested? && operator_steward?
    end

    def accept?
      managed_steward?
    end
    alias narrow? accept?
    alias suspend? accept?
    alias resume? accept?
    alias revoke? accept?

    def update?
      false
    end

    def destroy?
      false
    end

    # Edges touching a platform the agent stewards, on either side.
    class Scope < PlatformRecordPolicy::Scope
      def resolve
        return scope.none unless agent

        ids = steward_platform_ids
        scope.where(managed_platform_id: ids).or(scope.where(operator_platform_id: ids)).order(updated_at: :desc)
      end

      private

      def steward_platform_ids
        BetterTogether::Platform.joins(:person_platform_memberships)
                                .where(better_together_person_platform_memberships: { member_id: agent.id })
                                .distinct
                                .select { |platform| agent.platform_manager?(platform) }
                                .map(&:id)
      end
    end

    private

    def managed_steward?
      record.respond_to?(:managed_platform) && platform_steward?(record.managed_platform)
    end

    def operator_steward?
      record.respond_to?(:operator_platform) && platform_steward?(record.operator_platform)
    end

    def platform_steward?(platform)
      platform.present? && permitted_to?('manage_platform', platform)
    end
  end
end
