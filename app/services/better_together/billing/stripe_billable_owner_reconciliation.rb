# frozen_string_literal: true

module BetterTogether
  module Billing
    # Reconciles Stripe subscriptions for a single billable owner.
    class StripeBillableOwnerReconciliation
      Result = Struct.new(:billable_owner, :synced_count, :skipped_count, :subscription_ids, keyword_init: true)

      def call(billable_owner:)
        pay_customer = Pay::Customer.find_by(owner: billable_owner, processor: 'stripe')
        return Result.new(billable_owner:, synced_count: 0, skipped_count: 0, subscription_ids: []) unless pay_customer&.processor_id

        counts = reconcile_subscriptions(billable_owner, pay_customer.processor_id)
        Result.new(
          billable_owner:,
          synced_count: counts[:synced_count],
          skipped_count: counts[:skipped_count],
          subscription_ids: counts[:subscription_ids]
        )
      end

      private

      def stripe_subscriptions(customer_id)
        Stripe::Subscription.list(
          {
            customer: customer_id,
            status: 'all',
            limit: 100,
            expand: ['data.items.data.price']
          }
        )
      end

      def subscription_sync
        @subscription_sync ||= BetterTogether::Billing::StripeSubscriptionSync.new
      end

      def reconcile_subscriptions(billable_owner, processor_id)
        synced_count = 0
        skipped_count = 0
        subscription_ids = []

        stripe_subscriptions(processor_id).auto_paging_each do |subscription|
          subscription_ids << subscription.id
          result = subscription_sync.call(subscription:, billable_owner:, source: 'reconciliation')
          result.synced ? synced_count += 1 : skipped_count += 1
        end

        {
          synced_count:,
          skipped_count:,
          subscription_ids:
        }
      end
    end
  end
end
