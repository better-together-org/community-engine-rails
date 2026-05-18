# frozen_string_literal: true

module BetterTogether
  module Billing
    # Finds the Pay::Subscription matching the Stripe subscription object and
    # upserts the CE extension record (BetterTogether::Billing::Subscription).
    # Status, period, and processor details live on Pay::Subscription; this
    # service writes only CE-specific fields (billing plan, sync tracking).
    class StripeSubscriptionSync
      Result = Struct.new(
        :synced,
        :billing_subscription,
        :billing_plan,
        :reason,
        keyword_init: true
      )

      def call(subscription:, source: 'stripe_sync', event: nil, checkout_session_id: nil)
        pay_sub = find_pay_subscription(subscription)
        return Result.new(synced: false, reason: :pay_subscription_not_found) unless pay_sub

        billing_plan = resolve_billing_plan(subscription)
        return Result.new(synced: false, reason: :billing_plan_not_found) unless billing_plan

        persist_subscription(subscription, pay_sub, billing_plan, source:, event:, checkout_session_id:)
      end

      private

      def find_pay_subscription(subscription)
        Pay::Subscription.stripe.find_by(processor_id: subscription.id)
      end

      def build_subscription(pay_subscription)
        BetterTogether::Billing::Subscription.find_or_initialize_by(pay_subscription:)
      end

      # rubocop:disable Metrics/ParameterLists
      def persist_subscription(subscription, pay_sub, billing_plan, source:, event:, checkout_session_id:)
        billing_subscription = build_subscription(pay_sub)
        billing_subscription.assign_attributes(
          billing_plan:,
          beneficiary: resolve_beneficiary(subscription),
          last_synced_at: Time.current,
          sync_source: source,
          latest_processor_event_id: event&.id,
          latest_checkout_session_id: checkout_session_id
        )
        billing_subscription.save!

        Result.new(synced: true, billing_subscription:, billing_plan:, reason: :synced)
      end
      # rubocop:enable Metrics/ParameterLists

      def resolve_billing_plan(subscription)
        metadata = object_metadata(subscription)

        BetterTogether::Billing::Plan.find_by(id: metadata['bt_billing_plan_id']) ||
          BetterTogether::Billing::Plan.find_by(identifier: metadata['bt_billing_plan_identifier']) ||
          BetterTogether::Billing::Plan.find_by(stripe_price_id: stripe_price_id(subscription))
      end

      def resolve_beneficiary(subscription)
        metadata = object_metadata(subscription)

        BetterTogether::Billing::OwnershipResolver.resolve_record(
          metadata['bt_beneficiary_type'],
          metadata['bt_beneficiary_id']
        ) || BetterTogether::Billing::OwnershipResolver.resolve_record(
          'BetterTogether::Community',
          metadata['bt_community_id']
        )
      end

      def object_metadata(object)
        return {} unless object.respond_to?(:metadata)

        object.metadata.to_h
      end

      def stripe_price_id(subscription)
        line_item_price_id(subscription) || legacy_plan_price_id(subscription)
      end

      def line_item_price_id(subscription)
        return unless subscription.respond_to?(:items) && subscription.items.respond_to?(:data)

        first_item = subscription.items.data.first
        return unless first_item.respond_to?(:price)

        price = first_item.price
        price.id if price.respond_to?(:id)
      end

      def legacy_plan_price_id(subscription)
        return unless subscription.respond_to?(:plan)

        plan = subscription.plan
        plan.id if plan.respond_to?(:id)
      end
    end
  end
end
