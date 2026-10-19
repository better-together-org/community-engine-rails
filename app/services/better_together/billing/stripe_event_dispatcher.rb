# frozen_string_literal: true

module BetterTogether
  module Billing
    # Enqueues the Stripe events CE currently needs for local billing synchronization.
    class StripeEventDispatcher
      EVENT_TYPES = %w[
        stripe.checkout.session.completed
        stripe.account.updated
        stripe.account.application.deauthorized
        stripe.customer.subscription.created
        stripe.customer.subscription.updated
        stripe.customer.subscription.deleted
        stripe.customer.subscription.paused
        stripe.customer.subscription.resumed
        stripe.customer.subscription.trial_will_end
        stripe.price.created
        stripe.price.updated
        stripe.price.deleted
        stripe.product.created
        stripe.product.updated
      ].concat(
        BetterTogether::Billing::StripeFinancialEventSync::EVENT_TYPES.map { |event_type| "stripe.#{event_type}" }
      ).freeze

      def call(event)
        BetterTogether::Billing::ProcessStripeEventJob.perform_later(event.to_hash)
      end
    end
  end
end
