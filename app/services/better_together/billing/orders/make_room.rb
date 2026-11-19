# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # Frees room on an order for a new part, when the parts already waiting leave too little of the balance.
      #
      # A part that is only an intention can give way: a cash payment nobody has said they sent, or a processor
      # checkout that was not paid. The newest gives way first, and shrinks if it can (an offline part keeps
      # its place with a smaller amount) or is let go if it cannot (a processor checkout is cancelled; the
      # buyer pays that part again). A part that has money on its way is never touched: one the buyer has said
      # they sent, a cheque received, a payment the processor has in flight. If there is still not enough room,
      # it raises and nothing is changed.
      class MakeRoom
        class Refused < StandardError; end

        def self.call(...) = new(...).call

        def initialize(order:, amount_cents:)
          @order = order
          @amount_cents = amount_cents
        end

        def call
          shortfall = amount_cents - free_cents
          return if shortfall <= 0

          raise Refused, 'that part is already on its way' if shortfall > adjustable_cents

          adjustable.each do |payment|
            break if shortfall <= 0

            shortfall -= give_way(payment, shortfall)
          end
        end

        private

        attr_reader :order, :amount_cents

        def pending = order.payments.reload.in_flight.to_a

        def free_cents = order.balance_cents - pending.sum(&:amount_cents)

        # Newest first.
        def adjustable = pending.select { |payment| adjustable?(payment) }.sort_by(&:created_at).reverse

        def adjustable_cents = adjustable.sum(&:amount_cents)

        def adjustable?(payment)
          return false unless payment.pending?

          offline = payment.offline_payment
          offline ? offline.status == 'awaiting' : payment.remote?
        end

        # Returns how much room this part gave.
        def give_way(payment, shortfall)
          return let_go(payment) if payment.remote? || payment.amount_cents <= shortfall

          payment.update!(amount_cents: payment.amount_cents - shortfall)
          shortfall
        end

        def let_go(payment)
          given = payment.amount_cents
          offline = payment.offline_payment
          OfflinePayments::Transition.release(offline, 'cancelled') if offline
          Payments::Cancel.call(payment)
          given
        end
      end
    end
  end
end
