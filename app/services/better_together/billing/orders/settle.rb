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
            move_to(target) if target && target != order.status && holds_again?(target)
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

        def target_status
          return refund_status if refunded_cents.positive? && paid_cents.positive?
          return 'paid' if fully_paid? || covered_by_subscription?
          return 'partially_paid' if paid_cents.positive? && !order.paid?

          nil
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

          paid_cents >= order.total_cents
        end

        def refund_status = refunded_cents >= paid_cents ? 'refunded' : 'partially_refunded'

        # An expired order gave its holds back, so paying it must take them again. If a line can
        # no longer be held the order stays expired: the money is recorded and a steward refunds it.
        def holds_again?(target)
          return true unless order.expired? && %w[paid partially_paid].include?(target)

          Order.transaction(requires_new: true) do
            order.line_items.each { |line_item| line_item.purchasable.reserve!(quantity: line_item.quantity) }
          end
          true
        rescue StandardError => e
          Rails.logger.warn("[billing] expired order #{order.id} not revived: #{e.message}")
          false
        end

        def move_to(target)
          attributes = { status: target }
          attributes[:paid_at] = Time.current if target == 'paid' && order.paid_at.nil?
          order.update!(attributes)
          notify(target)
          follow_up_subscription if target == 'paid'
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
