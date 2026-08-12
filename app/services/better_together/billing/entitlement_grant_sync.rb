# frozen_string_literal: true

module BetterTogether
  module Billing
    # Grants or revokes the Billing::Entitlement rows a Billing::Plan
    # declares (Plan#granted_entitlement_keys) whenever its subscription or
    # one-time payment source successfully syncs. Called from
    # StripeEventProcessor on the authoritative webhook leg only — never
    # from the browser checkout-return leg, so there is exactly one source
    # of truth for what a purchase granted.
    class EntitlementGrantSync
      def call(billable_owner:, billing_plan:, source:)
        return if billable_owner.blank? || billing_plan.blank?
        return unless billable_owner.respond_to?(:entitled_to?)

        Array(billing_plan.granted_entitlement_keys).each do |key|
          grant_or_revoke(billable_owner, key, billing_plan, source)
        end
      end

      private

      def grant_or_revoke(holder, key, billing_plan, source)
        if grantable?(source)
          BetterTogether::Billing::Entitlement.grant!(holder:, entitlement_key: key, source:, billing_plan:)
        else
          BetterTogether::Billing::Entitlement.revoke!(holder:, entitlement_key: key, source:)
        end
      end

      # One-time payments have no ongoing status to re-check — a completed
      # payment stays granted. Subscriptions are re-evaluated on every sync,
      # using the same access boundary HostedEntitlementResolver reads.
      def grantable?(source)
        source.is_a?(BetterTogether::Billing::Subscription) ? source.access_active? : true
      end
    end
  end
end
