# frozen_string_literal: true

module BetterTogether
  module Billing
    # Finds the owner and billing plan for a completed one-time (mode:
    # 'payment') Stripe Checkout Session and upserts a local
    # Billing::OneTimePayment record. Mirrors StripeSubscriptionSync's shape,
    # but has no Pay::Subscription to look up — one-time payments have no
    # recurring processor state.
    class StripeOneTimePaymentSync
      Result = Struct.new(
        :synced,
        :one_time_payment,
        :billing_plan,
        :reason,
        keyword_init: true
      )

      def call(checkout_session:, payment_intent_id:)
        owner = resolve_owner(checkout_session)
        return Result.new(synced: false, reason: :owner_not_found) unless owner

        billing_plan = resolve_billing_plan(checkout_session)
        return Result.new(synced: false, reason: :billing_plan_not_found) unless billing_plan

        persist_payment(checkout_session, payment_intent_id, owner, billing_plan)
      end

      private

      def persist_payment(checkout_session, payment_intent_id, owner, billing_plan)
        one_time_payment = BetterTogether::Billing::OneTimePayment.find_or_initialize_by(
          stripe_checkout_session_id: checkout_session.id
        )
        one_time_payment.assign_attributes(
          owner:,
          billing_plan:,
          stripe_payment_intent_id: payment_intent_id,
          amount_cents: checkout_session.amount_total,
          currency: checkout_session.currency,
          status: 'succeeded',
          last_synced_at: Time.current
        )
        one_time_payment.save!

        Result.new(synced: true, one_time_payment:, billing_plan:, reason: :synced)
      end

      def resolve_owner(checkout_session)
        metadata = object_metadata(checkout_session)

        BetterTogether::Billing::OwnershipResolver.resolve_billable_owner(
          metadata:,
          fallback_owner: pay_customer_owner_for(checkout_session.customer)
        )
      end

      def resolve_billing_plan(checkout_session)
        metadata = object_metadata(checkout_session)

        BetterTogether::Billing::Plan.find_by(id: metadata['bt_billing_plan_id']) ||
          BetterTogether::Billing::Plan.find_by(identifier: metadata['bt_billing_plan_identifier']) ||
          BetterTogether::Billing::Plan.find_by(stripe_price_id: line_item_price_id(checkout_session))
      end

      def line_item_price_id(checkout_session)
        return unless checkout_session.respond_to?(:line_items) && checkout_session.line_items.respond_to?(:data)

        first_item = checkout_session.line_items.data.first
        return unless first_item.respond_to?(:price)

        price = first_item.price
        price.id if price.respond_to?(:id)
      end

      def object_metadata(object)
        return {} unless object.respond_to?(:metadata)

        object.metadata.to_h
      end

      def pay_customer_owner_for(customer_reference)
        customer_id = customer_reference.respond_to?(:id) ? customer_reference.id : customer_reference
        return if customer_id.blank?

        Pay::Customer.find_by(processor: 'stripe', processor_id: customer_id)&.owner
      end
    end
  end
end
