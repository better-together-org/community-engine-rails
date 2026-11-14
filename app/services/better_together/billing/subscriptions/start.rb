# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # Starts a subscription from a paid order for a recurring plan, paid by methods Community Engine settles
      # itself (in one part or several: credit and cash, say). It makes the Pay customer and subscription (a `Pay::Local::Subscription`, so Pay's
      # scopes and everything built on Pay's records see it like any other), the terms that hold what Pay
      # has no place for, and the first period, already paid by this order.
      #
      # Renewals are paid by the way the buyer chose to "renew with" (stored on the order). If they did not choose,
      # it is the way that paid the largest share of the first order, store credit only if nothing else did.
      #
      # The anchor every later period is counted from is when the order was really paid (see PaidTime).
      # Platform-sold plans only: a seller's subscription belongs to that seller.
      #
      # Safe to repeat: an order that already has its subscription returns it.
      class Start
        # What a subscription that costs nothing is renewed by: no way of paying, since there is nothing to pay.
        FREE_METHOD = 'free'

        def self.call(...) = new(...).call

        # Whether this order is the start of a subscription Community Engine will renew.
        def self.startable?(order)
          plan = single_plan(order)
          plan.present? && plan.recurring? && order.seller_id.blank? && order.pay_subscription_id.blank? &&
            order.purpose == 'subscription' && paid_locally?(order)
        end

        # The plan an order is for: its one line that is not an add-on. Add-ons (one-off extras) ride along on the order and
        # neither start a subscription nor give an entitlement of their own. Nothing when the lines are not plans, or when there
        # is not exactly one primary plan.
        def self.single_plan(order)
          purchasables = order.line_items.to_a.map(&:purchasable)
          return unless purchasables.all?(Plan)

          primary = purchasables.reject(&:add_on?)
          primary.first if primary.one?
        end

        # The line for that plan, whose price is the subscription's.
        def self.plan_line(order)
          plan = single_plan(order)
          order.line_items.to_a.find { |line| line.purchasable == plan } if plan
        end

        # Every part that paid it was settled by Community Engine; a part through a processor leaves the subscription to the processor.
        # An order that costs nothing has no payment to be settled by anyone else, so Community Engine keeps the subscription.
        def self.paid_locally?(order)
          return order.paid? if order.total_cents.zero?

          paid = order.payments.select(&:succeeded?)
          paid.any? && paid.all? { |payment| Billing.local_method?(payment.processor) }
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
          sync_entitlement(term)
          term
        end

        # The subscription is committed before its terms exist, so the change hook found nothing to give: ask once the terms are there.
        def sync_entitlement(term)
          ActiveRecord.after_all_transactions_commit { SyncEntitlementJob.perform_later(term.pay_subscription_id) }
        end

        def plan = @plan ||= self.class.single_plan(order)

        def anchor = @anchor ||= PaidTime.for(order)

        # What each renewal is paid by: what the buyer chose, else the way that paid the most (credit last).
        def renewal_method
          order.renewal_payment_method.presence || (FREE_METHOD if paid_by_method.empty?) || largest_share
        end

        def largest_share
          cash = paid_by_method.reject { |method, _| Billing.internal_method?(method) }
          (cash.presence || paid_by_method).max_by(&:last).first
        end

        def paid_by_method
          order.payments.select(&:succeeded?).group_by(&:processor).transform_values { |parts| parts.sum(&:amount_cents) }
        end

        def time_zone = order.platform.time_zone.presence || 'UTC'

        def first_period_end = Periods.ends_at(anchor:, plan:, sequence: 0, time_zone:)

        def customer = order.buyer.add_payment_processor(:local, platform: order.platform).api_record

        def build_subscription
          customer.subscribe(name: plan.identifier, plan: plan.identifier, current_period_start: anchor, current_period_end: first_period_end,
                             metadata: { bt_order_id: order.id, bt_plan_id: plan.id })
        end

        def build_term(subscription)
          order.platform.billing_subscription_terms.create!(
            pay_subscription: subscription, plan:, beneficiary: order.on_behalf_of, payment_method: renewal_method,
            unit_amount_cents: self.class.plan_line(order).unit_amount_cents, currency: order.currency, anchor_at: anchor
          )
        end
      end
    end
  end
end
