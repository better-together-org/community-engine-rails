# frozen_string_literal: true

module BetterTogether
  module Billing
    module Refunds
      # The tax inside a refund of `amount_cents`: the order's tax (added or already inside the prices) in proportion
      # to the amount given back, rounded half up. Once everything the order took in has been given back, the last
      # refund takes the tax that is left, so refunded tax never differs from the order's tax by a lost cent.
      class ProRatedTax
        def initialize(payment:, amount_cents:)
          @order = payment.order
          @payment = payment
          @amount_cents = amount_cents.to_i
        end

        def cents
          return 0 if order.tax_cents.to_i.zero? || order.total_cents.to_i.zero?

          completes_order? ? left : [share, left].min
        end

        private

        attr_reader :order, :payment, :amount_cents

        def share = (order.tax_cents * amount_cents).quo(order.total_cents).round(half: :up)

        def counted_refunds = Refund.where(payment: order.payments).select(&:counted?)

        def left = order.tax_cents - counted_refunds.sum(&:tax_cents)

        def completes_order? = counted_refunds.sum(&:amount_cents) + amount_cents >= order.paid_cents
      end
    end
  end
end
