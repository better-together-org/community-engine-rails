# frozen_string_literal: true

module BetterTogether
  module Billing
    module Entitlements
      # Takes away what an entitlement owns (a lapse or a refund): its memberships and feature grants made by it,
      # and its quota allowances. What it only adopted is left exactly as it was. Returns the failures.
      class ReleaseAll
        def self.call(entitlement)
          failures = []
          entitlement.grants.applied.find_each do |grant|
            release(grant)
          rescue StandardError => e
            BetterTogether.report_error(e, context: { entitlement_id: entitlement.id })
            failures << e
          end
          failures
        end

        # One grant: undone through the handler its copied kind and parameters name, then marked released, and
        # the quota's stored limit brought down if it was an allowance.
        def self.release(grant)
          handler = Registry.handler_for(grant)
          handler.release(grant)
          grant.release!
          return unless grant.kind == 'quota_allowance'

          Handlers::QuotaAllowance.sync(grant.entitlement.beneficiary, grant.quota_type)
        end
      end
    end
  end
end
