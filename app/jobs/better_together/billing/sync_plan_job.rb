# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pushes one Plan to its processor through the adapter: creates the processor-side
    # product and price when there is none yet, otherwise updates what the processor allows.
    #
    # Core owns the work around the adapter. It builds the platform's processor context,
    # supplies the idempotency key (so a retry cannot create a second product or price),
    # and stores the result; the adapter never writes the plan. When retries run out the
    # plan is marked failed with a short code a steward can read, never the processor's
    # own text.
    class SyncPlanJob < ApplicationJob
      ATTEMPTS = 10

      # Shown to stewards as better_together.billing.plans.sync_errors.<code>.
      ERROR_CODES = {
        'BetterTogether::Billing::ProcessorAdapter::LookupError' => 'processor_unavailable',
        'BetterTogether::Billing::SyncPlanJob::NotConfiguredError' => 'not_configured'
      }.freeze

      class NotConfiguredError < StandardError; end

      retry_on StandardError, wait: :polynomially_longer, attempts: ATTEMPTS do |job, error|
        job.send(:record_failure, error)
      end

      def perform(plan_id)
        # Loaded by id only; everything after this reads the platform from the plan.
        plan = BetterTogether::Billing::Plan.find_by(id: plan_id)
        return unless plan

        context = plan.processor_context
        adapter = plan.processor_adapter
        raise NotConfiguredError, 'no billing configuration for this plan' unless context && adapter&.supports?(:plan_sync)

        plan.apply_sync_result!(push(adapter, context, plan))
      end

      private

      def push(adapter, context, plan)
        result = adapter.sync_plan(context:, plan:, idempotency_key: plan.sync_idempotency_key)
        raise TypeError, "#{adapter.class}#sync_plan must return PlanSyncResult" unless result.is_a?(PlanSyncResult)

        result
      end

      def record_failure(error)
        plan = BetterTogether::Billing::Plan.find_by(id: arguments.first)
        plan&.record_sync_failure!(ERROR_CODES.fetch(error.class.name, 'processor_error'))
      end
    end
  end
end
