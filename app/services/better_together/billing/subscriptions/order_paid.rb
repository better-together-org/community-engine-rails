# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # A subscription order is paid. Either it is the first order of a recurring plan, which starts a
      # subscription (see Start), or it is a renewal invoice, which moves the subscription on.
      #
      # **Only a subscription Community Engine renews itself is handled here** (a method outside a processor:
      # cash, a cheque, an e-transfer, store credit). A subscription a processor renews arrives from the
      # processor and is linked with Subscriptions::Adopt.
      #
      # Safe to repeat: an order that already started or renewed a subscription changes nothing.
      class OrderPaid
        def self.call(order) = new(order).call

        def initialize(order)
          @order = order
        end

        def call
          return unless order.paid?

          term = renewing_term
          return start_or_nothing unless term

          plan_change?(term) ? ChangePlan.paid(term:, order:) : Renew.call(term:, order:, paid_at: PaidTime.for(order))
        end

        private

        def start_or_nothing = (Start.call(order:) if Start.startable?(order))

        # The invoice for a move to another plan right now, not a period's invoice.
        def plan_change?(term) = term.pending_plan_order_id == order.id

        attr_reader :order

        # The subscription this order renews, when it is a renewal invoice.
        def renewing_term
          subject = order.subject
          subject if subject.is_a?(SubscriptionTerm) && subject.platform_id == order.platform_id
        end
      end
    end
  end
end
