# frozen_string_literal: true

module BetterTogether
  module Billing
    # One-shot job that populates stripe_product_id on existing Billing::Plan
    # records that have a stripe_price_id but no stripe_product_id.
    #
    # Runs each plan in a separate SyncPlanToStripeJob to keep API calls
    # distributed and respect Stripe rate limits (2-second stagger).
    class BackfillStripeProductIdsJob < BetterTogether::ApplicationJob
      queue_as :default

      retry_on StandardError, wait: :polynomially_longer, attempts: 10

      def perform
        BetterTogether::Billing::Plan.needs_stripe_product_id.find_each.with_index do |plan, index|
          SyncPlanToStripeJob.set(wait: index * 2.seconds).perform_later(plan.id)
        end
      end
    end
  end
end
