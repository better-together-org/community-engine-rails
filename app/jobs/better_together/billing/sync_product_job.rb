# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pushes one Product, with all its prices, to its processor through the adapter (see CatalogSync). Core builds the context
    # and idempotency key and stores the result; when retries run out the product is marked failed with a short code a steward
    # can read, never the processor's own text.
    class SyncProductJob < ApplicationJob
      retry_on StandardError, wait: :polynomially_longer, attempts: SyncPlanJob::ATTEMPTS do |job, error|
        job.send(:record_failure, error)
      end

      def perform(product_id)
        product = BetterTogether::Billing::Product.find_by(id: product_id)
        return unless product&.processor.present?

        I18n.with_locale(Billing.platform_locale(product.platform)) { product.apply_sync_result!(CatalogSync.call(product)) }
      rescue CatalogSync::NotConfigured => e
        raise SyncPlanJob::NotConfiguredError, e.message
      end

      private

      def record_failure(error)
        product = BetterTogether::Billing::Product.find_by(id: arguments.first)
        product&.record_sync_failure!(SyncPlanJob::ERROR_CODES.fetch(error.class.name, 'processor_error'))
      end
    end
  end
end
