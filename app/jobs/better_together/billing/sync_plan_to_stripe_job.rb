# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pushes a single Plan to Stripe (Product + Price). Enqueued via
    # Plan#after_commit whenever the local record is created or updated.
    #
    # Idempotent: if Stripe already reflects the current state, StripePlanSync
    # returns :synced without making unnecessary API calls.
    class SyncPlanToStripeJob < BetterTogether::ApplicationJob
      queue_as :default

      retry_on StandardError, wait: :polynomially_longer, attempts: 10

      def perform(plan_id)
        plan = BetterTogether::Billing::Plan.find_by(id: plan_id)
        return unless plan

        BetterTogether::Billing::StripePlanSync.new.call(plan:)
      end
    end
  end
end
