# frozen_string_literal: true

module BetterTogether
  module Billing
    # Synchronizes Stripe Checkout completion into the local CE billing state.
    class StripeCheckoutSessionSync
      Result = Struct.new(
        :synced,
        :community,
        :billing_subscription,
        :billing_plan,
        :checkout_session,
        :reason,
        keyword_init: true
      )

      def call(checkout_session_id:, community: nil)
        checkout_session = fetch_checkout_session(checkout_session_id)
        subscription = fetch_subscription(checkout_session)

        return Result.new(checkout_session:, synced: false, reason: :no_subscription) unless subscription

        build_result(
          sync_subscription(
            subscription,
            checkout_session,
            community
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

      def resolve_community(checkout_session)
        metadata = object_metadata(checkout_session)

        BetterTogether::Community.find_by(id: metadata['bt_community_id']) ||
          pay_customer_for(checkout_session)&.owner
      end

      def pay_customer_for(checkout_session)
        customer_id = if checkout_session.respond_to?(:customer)
                        checkout_session.customer
                      end
        customer_id = customer_id.id if customer_id.respond_to?(:id)
        return if customer_id.blank?

        Pay::Customer.find_by(processor: 'stripe', processor_id: customer_id)
      end

      def object_metadata(object)
        return {} unless object.respond_to?(:metadata)

        object.metadata.to_h
      end

      def subscription_sync
        @subscription_sync ||= BetterTogether::Billing::StripeSubscriptionSync.new
      end

      def sync_subscription(subscription, checkout_session, community)
        subscription_sync.call(
          subscription:,
          community: community || resolve_community(checkout_session),
          source: 'checkout_return',
          checkout_session_id: checkout_session.id
        )
      end

      def build_result(sync_result, checkout_session)
        Result.new(
          synced: sync_result.synced,
          community: sync_result.community,
          billing_subscription: sync_result.billing_subscription,
          billing_plan: sync_result.billing_plan,
          checkout_session:,
          reason: sync_result.reason
        )
      end
    end
  end
end
