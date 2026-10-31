# frozen_string_literal: true

module BetterTogether
  # Access control for materialized quota balances. QuotaBalance has no owner column
  # of its own (only quota_id + period_key) - visibility is always derived from its
  # Quota's owner, same conservative scoping as QuotaPolicy.
  class QuotaBalancePolicy < PlatformRecordPolicy
    def index?
      user.present?
    end

    def show?
      return false unless user.present?

      record.quota.owner == agent || permitted_to?('manage_platform', current_platform)
    end

    # Filters to balances whose Quota is owned by the caller, or everything for a
    # platform manager.
    class Scope < PlatformRecordPolicy::Scope
      def resolve
        joined = platform_scoped(scope.joins(:quota))
        return joined if permitted_to?('manage_platform', current_platform)
        return scope.none unless agent

        joined.merge(BetterTogether::Quota.where(owner: agent))
      end
    end
  end
end
