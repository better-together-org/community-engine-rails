# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # What a steward does about the money against an order that will not be completed: each paid part is returned,
      # then the order can be cancelled (see Cancel, which refuses while money is still against it).
      #
      # How a part goes back depends on how it was paid:
      #
      # * store credit goes back onto the buyer's balance, at once, to the lots it came from. `call` does this for every
      #   credit part in one step;
      # * cash, a cheque or an e-transfer is money the seller holds: the platform cannot move it, so the seller says they
      #   handed it back (the refund form on the sale, see SaleRefundsController);
      # * a processor refunds at the vendor, and the webhook records it.
      #
      # `pending` lists what is still to be returned and how, for the sale page.
      class ReturnPayments
        Part = Data.define(:payment, :kind) do
          def cents = payment.refundable_cents
        end

        def self.call(...) = new(...).call

        def self.pending(order) = new(order:, actor: nil).pending

        def initialize(order:, actor:)
          @order = order
          @actor = actor
        end

        # Returns the credit parts; the rest are the seller's or the processor's to do. Gives what is left to return.
        def call
          pending.select { |part| part.kind == :credit }.each { |part| give_back(part.payment) }
          pending
        end

        # Each paid part with something left to return, and who returns it: :credit (automatic), :manual (the seller), :processor.
        def pending
          returnable = order.payments.reload.select { |payment| payment.refundable_cents.positive? }
          returnable.map { |payment| Part.new(payment:, kind: kind_of(payment)) }
        end

        private

        attr_reader :order, :actor

        def kind_of(payment)
          return :credit if Billing.internal_method?(payment.processor)

          Billing.local_method?(payment.processor) ? :manual : :processor
        end

        def give_back(payment)
          Refunds::Record.call(payment:, amount_cents: payment.refundable_cents, idempotency_key: "return:#{payment.id}",
                               reason: 'cancelled_order', recorded_by: actor, notify: false)
        end
      end
    end
  end
end
