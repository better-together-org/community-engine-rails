# frozen_string_literal: true

module BetterTogether
  module Billing
    # Synchronizes Stripe Checkout completion into the local CE billing state.
    # Owner resolution is implicit: pay matches the Stripe customer to the
    # pay_customer record and its owner (Person or Community).
    class StripeCheckoutSessionSync
      Result = Struct.new(
        :synced,
        :billing_subscription,
        :billing_plan,
        :checkout_session,
        :reason,
        keyword_init: true
      )

      def call(checkout_session_id:)
        checkout_session = fetch_checkout_session(checkout_session_id)
        subscription = fetch_subscription(checkout_session)

        return Result.new(checkout_session:, synced: false, reason: :no_subscription) unless subscription

        build_result(
          subscription_sync.call(
            subscription:,
            source: 'checkout_return',
            checkout_session_id: checkout_session.id
          ),
          checkout_session
        )
      end

      private

      def fetch_checkout_session(checkout_session_id)
        Stripe::Checkout::Session.retrieve(
          {
            id: checkout_session_id,
            expand: %w[subscription customer line_items.data.price]
          }
        )
      end

      def fetch_subscription(checkout_session)
        return unless checkout_session.respond_to?(:subscription)

        subscription = checkout_session.subscription
        return if subscription.blank?
        return subscription unless subscription.is_a?(String)

        Stripe::Subscription.retrieve(
          {
            id: subscription,
            expand: ['items.data.price']
          }
        )
      end

      def subscription_sync
        @subscription_sync ||= BetterTogether::Billing::StripeSubscriptionSync.new
      end

      def build_result(sync_result, checkout_session)
        Result.new(
          synced: sync_result.synced,
          billing_subscription: sync_result.billing_subscription,
          billing_plan: sync_result.billing_plan,
          checkout_session:,
          reason: sync_result.reason
        )
      end
    end
  end
end
