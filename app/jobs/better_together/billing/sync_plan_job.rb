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

        # The processor is told the platform's own language, whoever enqueued the job.
        I18n.with_locale(Billing.platform_locale(plan.platform)) { plan.apply_sync_result!(push(plan)) }
      end

      private

      # Through CatalogSync, which speaks whichever contract version the adapter implements.
      def push(plan)
        result = CatalogSync.call(plan)
        PlanSyncResult.new(product_id: result.product_id, price: result.price_for(plan.id) || result.prices.first)
      rescue CatalogSync::NotConfigured => e
        raise NotConfiguredError, e.message
      end

      def record_failure(error)
        plan = BetterTogether::Billing::Plan.find_by(id: arguments.first)
        return unless plan

        plan.record_sync_failure!(ERROR_CODES.fetch(error.class.name, 'processor_error'))
        tell_stewards(plan)
      end

      # The platform's stewards are told a plan could not be pushed, once per failed attempt. A plan
      # a community or person sells is theirs to hear about.
      def tell_stewards(plan)
        return unless plan.sold_by_platform?

        Notifications.deliver('plan_sync_failed', subject: plan, dedupe_key: "plan-sync:#{plan.id}:#{plan.sync_attempted_at.to_i}")
      end
    end
  end
end
