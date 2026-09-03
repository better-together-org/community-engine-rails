# frozen_string_literal: true

module BetterTogether
  module Billing
    # Reconciles Stripe subscriptions for a single billable owner.
    class ReconcileStripeBillableOwnerBillingJob < BetterTogether::ApplicationJob
      queue_as :default

      retry_on StandardError, wait: :polynomially_longer, attempts: 10

      def perform(billable_owner_type, billable_owner_id)
        billable_owner = OwnershipResolver.resolve_record(billable_owner_type, billable_owner_id)
        return unless billable_owner

        BetterTogether::Billing::StripeBillableOwnerReconciliation.new.call(billable_owner:)
      end
    end
  end
end
