# frozen_string_literal: true

module BetterTogether
  # Access control for quota usage ledger rows. Same conservative scoping as
  # QuotaPolicy: readable by the usage's own owner, or a platform manager.
  class QuotaUsagePolicy < PlatformRecordPolicy
    def index?
      user.present?
    end

    def show?
      return false unless user.present?

      record.owner == agent || permitted_to?('manage_platform', current_platform)
    end

    # Filters to the caller's own usage rows, or everything for a platform manager.
    class Scope < PlatformRecordPolicy::Scope
      def resolve
        return platform_scoped if permitted_to?('manage_platform', current_platform)
        return scope.none unless agent

        platform_scoped.where(owner: agent)
      end
    end
  end
end
