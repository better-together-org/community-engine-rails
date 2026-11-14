# frozen_string_literal: true

module BetterTogether
  module Billing
    # Brings what a subscription gives in line with the subscription (see Entitlements::Sync). Run after the
    # subscription changed, as a job that can be retried, so a failure here can never undo a payment. Safe to repeat.
    class SyncEntitlementJob < ApplicationJob
      retry_on Entitlements::Sync::Incomplete, wait: :polynomially_longer, attempts: 5

      # `pay_subscription_id` rather than the record: the subscription may be one of Pay's STI classes.
      def perform(pay_subscription_id)
        subscription = Pay::Subscription.find_by(id: pay_subscription_id)
        term = subscription && BetterTogether::Billing::SubscriptionTerm.find_by(pay_subscription_id: subscription.id)
        Entitlements::Sync.subscription(term) if term
      end
    end
  end
end
