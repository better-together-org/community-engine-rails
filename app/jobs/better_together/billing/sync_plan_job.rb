# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pushes one Plan to its processor through the adapter. Enqueued from Plan's
    # after_commit; the adapter makes the push idempotent.
    class SyncPlanJob < BetterTogether::ApplicationJob
      queue_as :default

      retry_on StandardError, wait: :polynomially_longer, attempts: 10

      def perform(plan_id)
        plan = BetterTogether::Billing::Plan.find_by(id: plan_id)
        return unless plan

        adapter = BetterTogether::Billing.processor_adapter(plan.processor)
        return unless adapter&.supports?(:plan_sync)

        adapter.sync_plan(plan:)
      end
    end
  end
end
