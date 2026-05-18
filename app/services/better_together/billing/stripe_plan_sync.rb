# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pushes a local BetterTogether::Billing::Plan to Stripe, creating or
    # updating both the Product and the Price as needed.
    #
    # CE owns name and description; it does NOT overwrite active from Stripe.
    # Price fields (amount, currency, interval) are immutable once a Stripe
    # Price is linked — this service archives the old Price and creates a new
    # one when they differ (a Stripe constraint, not a CE choice).
    #
    # Ownership boundary:
    #   CE → Stripe  : name, description, active, metadata
    #   Stripe → CE  : active (via StripePriceSync on price.updated webhook)
    #   Immutable     : amount_cents, currency, billing_interval (after link)
    class StripePlanSync
      Result = Struct.new(
        :synced,
        :plan,
        :stripe_product_id,
        :stripe_price_id,
        :reason,
        keyword_init: true
      )

      # rubocop:disable Metrics/AbcSize
      def call(plan:)
        return Result.new(synced: false, plan:, reason: :no_stripe_price_id) if plan.stripe_price_id.blank?
        return Result.new(synced: false, plan:, reason: :stripe_initiated) if plan.sync_source == 'stripe_webhook'

        product = upsert_product(plan)
        return Result.new(synced: false, plan:, reason: :product_upsert_failed) unless product

        price = ensure_price(plan, product)
        return Result.new(synced: false, plan:, reason: :price_upsert_failed) unless price

        mark_synced(plan, product, price)
        success_result(plan, product, price)
      rescue Stripe::StripeError => e
        Rails.logger.error("StripePlanSync failed for plan #{plan.id}: #{e.message}")
        Result.new(synced: false, plan:, reason: :stripe_error)
      end
      # rubocop:enable Metrics/AbcSize

      private

      def success_result(plan, product, price)
        Result.new(
          synced: true, plan:,
          stripe_product_id: product.id,
          stripe_price_id: price.id,
          reason: :synced
        )
      end

      def upsert_product(plan)
        if plan.stripe_product_id.present?
          update_product(plan)
        else
          create_product(plan)
        end
      end

      def create_product(plan)
        Stripe::Product.create(
          name: plan.name,
          description: plan.description.presence,
          active: plan.active,
          metadata: { bt_billing_plan_id: plan.id, bt_billing_plan_identifier: plan.identifier }
        )
      end

      def update_product(plan)
        Stripe::Product.update(
          plan.stripe_product_id,
          {
            name: plan.name,
            description: plan.description.presence,
            active: plan.active,
            metadata: { bt_billing_plan_id: plan.id, bt_billing_plan_identifier: plan.identifier }
          }
        )
      end

      def ensure_price(plan, product)
        existing = Stripe::Price.retrieve(plan.stripe_price_id)
        return existing if price_matches?(existing, plan)

        # Stripe Prices are immutable; archive the old one and create a new one.
        Stripe::Price.update(plan.stripe_price_id, active: false)
        create_price(plan, product)
      rescue Stripe::InvalidRequestError
        create_price(plan, product)
      end

      def create_price(plan, product)
        Stripe::Price.create(
          product: product.id,
          unit_amount: plan.amount_cents,
          currency: plan.currency.downcase,
          **recurring_params(plan),
          metadata: { bt_billing_plan_id: plan.id }
        )
      end

      def price_matches?(price, plan)
        price.unit_amount == plan.amount_cents &&
          price.currency.casecmp(plan.currency).zero? &&
          interval_matches?(price, plan)
      end

      def interval_matches?(price, plan)
        return price.type == 'one_time' if plan.billing_interval == 'one_time'

        price.recurring&.interval == plan.billing_interval
      end

      def recurring_params(plan)
        return {} if plan.billing_interval == 'one_time'

        { recurring: { interval: plan.billing_interval } }
      end

      def mark_synced(plan, product, price)
        updates = { synced_to_stripe_at: Time.current, sync_source: 'ce_push', latest_stripe_event_id: nil }
        updates[:stripe_product_id] = product.id if product.id != plan.stripe_product_id
        updates[:stripe_price_id] = price.id if price.id != plan.stripe_price_id
        plan.update_columns(**updates)
      end
    end
  end
end
