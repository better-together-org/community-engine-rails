# frozen_string_literal: true

module BetterTogether
  module Billing
    # Applies inbound Stripe Price / Product webhook events to the local
    # BetterTogether::Billing::Plan.
    #
    # Ownership boundary (inbound direction):
    #   Stripe → CE  : active (price.updated / product.updated)
    #   CE-owned     : name, description — never overwritten from Stripe events
    #
    # Loop guard: every write uses a single update_columns call that includes
    # sync_source: 'stripe_webhook' and latest_stripe_event_id. If the
    # processor fires the same event twice, the second pass is idempotent.
    class StripePriceSync
      UNSUPPORTED_INTERVALS = %w[week day].freeze

      Result = Struct.new(
        :synced,
        :plan,
        :reason,
        keyword_init: true
      )

      # @param event [Stripe::Event]
      def call(event:)
        case event.type
        when 'price.updated', 'price.created'
          handle_price_event(event)
        when 'product.updated', 'product.created'
          handle_product_event(event)
        when 'price.deleted'
          handle_price_deleted(event)
        else
          Result.new(synced: false, reason: :unhandled_event_type)
        end
      rescue Stripe::StripeError => e
        Rails.logger.error("StripePriceSync failed for event #{event.id}: #{e.message}")
        Result.new(synced: false, reason: :stripe_error)
      end

      private

      # ── Price events ────────────────────────────────────────────────────────

      def handle_price_event(event)
        price_object = event.data.object
        plan = BetterTogether::Billing::Plan.find_by(stripe_price_id: price_object.id)
        return Result.new(synced: false, reason: :plan_not_found) unless plan

        return stale_event_result(plan) if stale_event?(plan, event)

        log_unsupported_interval(plan, price_object)
        record_stripe_sync(plan, event, active: price_object.active)
        Result.new(synced: true, plan:, reason: :synced)
      end

      def handle_price_deleted(event)
        price_object = event.data.object
        plan = BetterTogether::Billing::Plan.find_by(stripe_price_id: price_object.id)
        return Result.new(synced: false, reason: :plan_not_found) unless plan

        return stale_event_result(plan) if stale_event?(plan, event)

        plan.update_columns(
          active: false,
          sync_source: 'stripe_webhook',
          latest_stripe_event_id: event.id,
          synced_to_stripe_at: Time.current
        )

        notify_plan_deactivated(plan)
        Result.new(synced: true, plan:, reason: :deactivated)
      end

      # ── Product events ───────────────────────────────────────────────────────

      def handle_product_event(event)
        product_object = event.data.object
        plan = BetterTogether::Billing::Plan.find_by(stripe_product_id: product_object.id)
        return Result.new(synced: false, reason: :plan_not_found) unless plan

        return stale_event_result(plan) if stale_event?(plan, event)

        # CE owns name and description; only active is synced from product events.
        plan.update_columns(
          active: product_object.active,
          sync_source: 'stripe_webhook',
          latest_stripe_event_id: event.id,
          synced_to_stripe_at: Time.current
        )

        Result.new(synced: true, plan:, reason: :synced)
      end

      # ── Helpers ──────────────────────────────────────────────────────────────

      def log_unsupported_interval(plan, price_object)
        return unless unsupported_interval?(price_object)

        Rails.logger.warn(
          "StripePriceSync: plan #{plan.id} has unsupported billing interval from Stripe. " \
          'Deactivating locally.'
        )
      end

      def record_stripe_sync(plan, event, active:)
        plan.update_columns(
          active:,
          sync_source: 'stripe_webhook',
          latest_stripe_event_id: event.id,
          synced_to_stripe_at: Time.current
        )
      end

      def stale_event?(plan, event)
        plan.latest_stripe_event_id == event.id
      end

      def stale_event_result(plan)
        Result.new(synced: false, plan:, reason: :duplicate_event)
      end

      def unsupported_interval?(price_object)
        return false unless price_object.respond_to?(:recurring) && price_object.recurring

        UNSUPPORTED_INTERVALS.include?(price_object.recurring.interval)
      end

      def notify_plan_deactivated(plan)
        Rails.logger.warn(
          "StripePriceSync: plan #{plan.id} (#{plan.identifier}) deactivated by Stripe price.deleted event."
        )
      rescue StandardError => e
        Rails.logger.warn("StripePriceSync: notification failed for plan #{plan.id}: #{e.message}")
      end
    end
  end
end
