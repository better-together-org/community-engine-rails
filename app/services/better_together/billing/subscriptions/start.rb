# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # Starts a subscription from a paid order for a recurring plan, paid by a method Community Engine
      # settles itself. It makes the Pay customer and subscription (a `Pay::Local::Subscription`, so Pay's
      # scopes and everything built on Pay's records see it like any other), the terms that hold what Pay
      # has no place for, and the first period, already paid by this order.
      #
      # The anchor every later period is counted from is when the order was really paid (see PaidTime).
      # Platform-sold plans only: a seller's subscription belongs to that seller.
      #
      # Safe to repeat: an order that already has its subscription returns it.
      class Start
        def self.call(...) = new(...).call

        # Whether this order is the start of a subscription Community Engine will renew.
        def self.startable?(order)
          plan = single_plan(order)
          plan.present? && plan.recurring? && order.seller_id.blank? && order.pay_subscription_id.blank? &&
            order.purpose == 'subscription' && paid_locally?(order)
        end

        def self.single_plan(order)
          lines = order.lines.to_a
          lines.first.purchasable if lines.one? && lines.first.purchasable.is_a?(Plan)
        end

        def self.paid_locally?(order)
          payment = order.payments.find(&:succeeded?)
          payment.present? && Billing.local_method?(payment.processor)
        end

        def initialize(order:)
          @order = order
        end

        def call
          return order.subject if order.subject.is_a?(SubscriptionTerm)
          return unless self.class.startable?(order)

          Order.transaction { start }
        end

        private

        attr_reader :order

        def start
          term = build_term(build_subscription)
          term.periods.create!(platform_id: order.platform_id, sequence: 0, starts_at: anchor, ends_at: term.period_end(0), status: 'paid',
                               order:, paid_at: anchor)
          order.update!(subject: term, pay_subscription: term.pay_subscription)
          term
        end

        def plan = @plan ||= self.class.single_plan(order)

        def anchor = @anchor ||= PaidTime.for(order)

        def payment = order.payments.find(&:succeeded?)

        def time_zone = order.platform.time_zone.presence || 'UTC'

        def first_period_end = Periods.ends_at(anchor:, plan:, sequence: 0, time_zone:)

        def customer = order.buyer.add_payment_processor(:local, platform: order.platform).api_record

        def build_subscription
          customer.subscribe(name: plan.identifier, plan: plan.identifier, current_period_start: anchor, current_period_end: first_period_end,
                             metadata: { bt_order_id: order.id, bt_plan_id: plan.id })
        end

        def build_term(subscription)
          order.platform.billing_subscription_terms.create!(
            pay_subscription: subscription, plan:, beneficiary: order.on_behalf_of, payment_method: payment.processor,
            unit_amount_cents: order.lines.first.unit_amount_cents, currency: order.currency, anchor_at: anchor
          )
        end
      end
    end
  end
end
