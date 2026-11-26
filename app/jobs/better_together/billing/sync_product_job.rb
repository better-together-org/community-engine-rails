# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pushes one product (a plan is one) and its prices to its processor through the adapter: creates the processor-side product and
    # prices when there are none yet, otherwise updates what the processor allows.
    #
    # Core owns the work around the adapter. It builds the platform's processor context, supplies the idempotency key (so a retry
    # cannot create a second product or price), and stores the result; the adapter never writes the product. When retries run out
    # the product is marked failed with a short code a steward can read, never the processor's own text.
    class SyncProductJob < ApplicationJob
      ATTEMPTS = 10

      # Shown to stewards as better_together.billing.plans.sync_errors.<code>.
      ERROR_CODES = {
        'BetterTogether::Billing::ProcessorAdapter::LookupError' => 'processor_unavailable',
        'BetterTogether::Billing::SyncProductJob::NotConfiguredError' => 'not_configured'
      }.freeze

      class NotConfiguredError < StandardError; end

      retry_on StandardError, wait: :polynomially_longer, attempts: ATTEMPTS do |job, error|
        job.send(:record_failure, error)
      end

      def perform(product_id)
        # Loaded by id only; everything after this reads the platform from the product.
        product = BetterTogether::Billing::Product.find_by(id: product_id)
        return unless product&.processor.present?

        # The processor is told the platform's own language, whoever enqueued the job.
        I18n.with_locale(Billing.platform_locale(product.platform)) { product.apply_sync_result!(CatalogSync.call(product)) }
      rescue CatalogSync::NotConfigured => e
        raise NotConfiguredError, e.message
      end

      private

      def record_failure(error)
        product = BetterTogether::Billing::Product.find_by(id: arguments.first)
        return unless product

        product.record_sync_failure!(ERROR_CODES.fetch(error.class.name, 'processor_error'))
        tell_stewards(product)
      end

      # The platform's stewards are told a plan could not be pushed, once per failed attempt. A plan a community or person
      # sells is theirs to hear about.
      def tell_stewards(product)
        return unless product.is_a?(Plan) && product.sold_by_platform?

        Notifications.deliver('plan_sync_failed', subject: product, dedupe_key: "plan-sync:#{product.id}:#{product.sync_attempted_at.to_i}")
      end
    end
  end
end
