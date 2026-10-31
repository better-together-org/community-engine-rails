# frozen_string_literal: true

module BetterTogether
  # Access control for quota rows. Deliberately conservative for this first cut: an
  # owner (Person/Community/Platform) can read its own quotas, and a platform
  # manager can read everything. There is no "community admin reads their
  # community's quota" path yet - that's a product permission question (likely a
  # new permission like manage_community_quotas, per the original Phase 5a plan's
  # own note on AccessControlBuilder), not an engineering default to invent here.
  class QuotaPolicy < PlatformRecordPolicy
    def index?
      user.present?
    end

    def show?
      return false unless user.present?

      record.owner == agent || permitted_to?('manage_platform', current_platform)
    end

    # Filters to the caller's own quotas, or everything for a platform manager.
    class Scope < PlatformRecordPolicy::Scope
      def resolve
        return platform_scoped if permitted_to?('manage_platform', current_platform)
        return scope.none unless agent

        platform_scoped.where(owner: agent)
      end
    end
  end
end
