# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # Works out where an order stands from its payments and refunds, and moves it there.
      #
      # The order is locked while this runs, so two payments arriving together settle it one
      # after the other. Settling is idempotent: with nothing new it changes nothing.
      class Settle
        def self.call(order) = new(order).call

        def initialize(order)
          @order = order
        end

        def call
          order.with_lock do
            order.reload
            # A cancelled order stays cancelled: money that arrives for it is refunded (Payments::Succeed).
            next if order.cancelled?

            target = target_status
            move_to(target) if target && target != order.status
          end
          order
        end

        private

        attr_reader :order

        def payments = order.payments.reload

        def paid_cents = payments.select { |payment| counts_as_paid?(payment) }.sum(&:amount_cents)

        # A refunded payment was paid; it is the refund that changes the order's state.
        def counts_as_paid?(payment) = %w[succeeded partially_refunded refunded].include?(payment.status)

        def refunded_cents = payments.sum(&:refunded_cents)

        # What is still against the order. Parts that were returned no longer count.
        def net_paid_cents = paid_cents - refunded_cents

        # Where the order stands. Paid in full is judged on what is still against it, so returning one part of a
        # partly paid order puts it back to partly paid (or waiting), and an order that was once paid in full and
        # then returned keeps the refund states.
        def target_status
          return 'paid' if fully_paid? || covered_by_subscription?
          return refund_status if order.paid_at.present? && refunded_cents.positive?
          return 'partially_paid' if net_paid_cents.positive?

          'awaiting_payment' if order.partially_paid?
        end

        # The first payment of a subscription that is on a trial (or fully discounted) is paid by no
        # payment: Pay says the subscription is trialing or active, and nothing is owed yet.
        def covered_by_subscription?
          subscription = order.pay_subscription
          subscription.present? && order.open? && payments.none? && (subscription.on_trial? || subscription.active?)
        end

        # An order that costs nothing is paid by no payment at all, once it is placed.
        def fully_paid?
          return order.open? if order.total_cents.zero?

          net_paid_cents >= order.total_cents
        end

        def refund_status = refunded_cents >= paid_cents ? 'refunded' : 'partially_refunded'

        def move_to(target)
          attributes = { status: target }
          attributes[:paid_at] = Time.current if target == 'paid' && order.paid_at.nil?
          order.update!(attributes)
          notify(target)
          follow_up_subscription if target == 'paid'
          follow_up_entitlement if %w[paid refunded cancelled].include?(target)
        end

        # What a one-time plan includes is given when the order is paid and taken away if it is refunded. Queued
        # after the change commits, like the subscription follow-up, so it can be retried and never undo a payment.
        def follow_up_entitlement
          return unless order.lines.any? { |line| line.purchasable.is_a?(Plan) && !line.purchasable.recurring? }

          ActiveRecord.after_all_transactions_commit { SyncOrderEntitlementJob.perform_later(order) }
        end

        # A paid subscription order starts a subscription, or renews one. It runs after the payment is
        # committed, as a job that can be retried, so a failure there can never undo a recorded payment.
        def follow_up_subscription
          return unless order.purpose == 'subscription'

          ActiveRecord.after_all_transactions_commit { SubscriptionOrderPaidJob.perform_later(order) }
        end

        # Told once per order and outcome, however many times the order is settled.
        def notify(target)
          kind = { 'paid' => 'order_paid' }[target]
          Notifications.deliver(kind, subject: order) if kind
        end
      end
    end
  end
end
