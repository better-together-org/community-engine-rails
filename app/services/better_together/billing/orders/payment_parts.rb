# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # The parts an order is to be paid in, as asked for when it is placed: each a way of paying and an amount, or
      # no amount for "the rest". Any way of paying can be a part, store credit included, and several parts can
      # complete an order.
      #
      #   PaymentParts.new([{ payment_method: 'store_credit' }, { payment_method: 'cash' }], ...)
      #     # all the credit the buyer can spend, then the rest in cash
      #
      # Checked before anything is saved: each way is usable for this order (see PaymentChoice), amounts are
      # positive and do not pass the total, and only one part takes "the rest" (store credit may also say "all I can
      # spend"; it is taken first, whatever order the parts are named in).
      class PaymentParts
        Part = Data.define(:payment_method, :amount_cents) do
          def credit? = Billing.internal_method?(payment_method)
          def rest? = amount_cents.nil?
        end

        def initialize(parts, platform:, seller:, purpose:, currency:, line_items:) # rubocop:disable Metrics/ParameterLists
          @parts = Array(parts).map { |part| build(part) }
          @platform = platform
          @seller = seller
          @purpose = purpose
          @currency = currency
          @line_items = line_items
        end

        attr_reader :parts

        def any? = parts.any?

        def methods_named = parts.map(&:payment_method).uniq

        # Why the parts cannot be used, or nil.
        def problem
          shape_problem || parts.lazy.filter_map { |part| choice(part).problem }.first
        end

        # The seller's own hold time, from the first part paid by a method the seller confirms by hand.
        def hold_hours = parts.lazy.filter_map { |part| choice(part).offline_setting&.hold_hours }.first

        # Opens every part on the placed order, explicit amounts first, then the credit that takes all it can, then the rest.
        def open(order, seller_assisted: false)
          ordered.each_with_index do |part, index|
            next if part.rest? && !part.credit? && order.reload.balance_cents.zero? # credit already covered it all

            AddPayment.call(order:, payment_method: part.payment_method, amount_cents: part.amount_cents, seller_assisted:,
                            idempotency_key: "placed-#{index}")
          end
        end

        private

        attr_reader :platform, :seller, :purpose, :currency, :line_items

        def build(part)
          values = part.to_h.symbolize_keys
          Part.new(payment_method: values[:payment_method].to_s, amount_cents: values[:amount_cents].presence&.to_i)
        end

        # Explicit amounts first, then credit taking all it can, then whatever takes the rest.
        def ordered = parts.each_with_index.sort_by { |part, index| [rank(part), index] }.map(&:first)

        def rank(part)
          return 0 unless part.rest?

          part.credit? ? 1 : 2
        end

        # What the line items come to, at the price each was sold at.
        def total_cents
          line_items.sum { |line_item| line_item.fetch(:unit_amount_cents) { line_item.fetch(:purchasable).purchasable_amount_cents } * line_item.fetch(:quantity, 1) }
        end

        def choice(part) = PaymentChoice.new(platform:, seller:, name: part.payment_method, purpose:, currency:)

        def shape_problem
          return 'name a way of paying for each part' if parts.any? { |part| part.payment_method.blank? }
          return 'a part must be more than nothing' if parts.any? { |part| !part.rest? && !part.amount_cents.positive? }

          amount_problem
        end

        def amount_problem
          return 'the parts are more than the order' if parts.sum { |part| part.amount_cents.to_i } > total_cents

          'only one part can take the rest' if parts.many? { |part| part.rest? && !part.credit? }
        end
      end
    end
  end
end
