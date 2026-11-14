# frozen_string_literal: true

module BetterTogether
  module Billing
    module Entitlements
      # The quota framework's allowance provider for paid plans (registered with Quotas::Allowances). It answers
      # two questions about an owner and a quota type:
      #
      # * `amount`: the extra allowance on top of the default, the sum of the live entitlements' applied grants.
      #   An entitlement in its grace still counts: the holder has not lost anything yet.
      # * `pool?`: whether usage in this owner's content is charged to it. A community whose plan carries an
      #   allowance is a pool, so what its members upload counts against the community, not each uploader.
      #
      # With billing switched off (BT_BILLING_ENABLED) it answers 0 and false without a query, so quota checks
      # on unrelated requests cost nothing.
      #
      # Nothing is ever reduced or deleted here. When an allowance goes, the limit drops, usage stays, and only
      # new consumption is refused (when enforcement is on).
      module QuotaAllowances
        module_function

        def amount(owner:, type:)
          return 0 unless Configuration.requested?

          live_grants(owner, type).sum(:amount)
        end

        def pool?(owner:, type:)
          return false unless Configuration.requested?

          owner.is_a?(BetterTogether::Community) && live_grants(owner, type).exists?
        end

        def live_grants(owner, type)
          EntitlementGrant.applied.allowances.where(quota_type: type.to_s)
                          .where(entitlement_id: Entitlement.live.where(beneficiary_type: owner.class.name,
                                                                        beneficiary_id: owner.id).select(:id))
        end
      end
    end
  end
end
