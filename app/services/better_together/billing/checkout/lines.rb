# frozen_string_literal: true

module BetterTogether
  module Billing
    module Checkout
      # The lines of a processor checkout session and the session's mode, worked out from the order's lines.
      #
      # Mode is `:subscription` when any line recurs (one-time lines then ride on the first invoice) and `:payment` when
      # every line is one-time. A plan line names the processor price the plan is linked to. A price line names its own
      # processor price when its product is held by this processor and it has one, and otherwise is sent inline, so a
      # product needs no copy in the processor's catalog to be sold through it.
      #
      #   Checkout::Lines.call(order:, processor: 'stripe')  # => Lines::Result(mode: :payment, lines: [CheckoutLine, ...])
      class Lines
        Result = Data.define(:mode, :lines)

        class Unmirrored < StandardError; end

        def self.call(...) = new(...).call

        def initialize(order:, processor:)
          @order = order
          @processor = processor.to_s
        end

        def call
          lines = order.line_items.includes(:purchasable).order(:position, :created_at).map { |line_item| line_for(line_item) }
          Result.new(mode: lines.any?(&:recurring?) ? :subscription : :payment, lines:)
        end

        private

        attr_reader :order, :processor

        def line_for(line_item)
          purchasable = line_item.purchasable
          raise Unmirrored, "#{purchasable.class} cannot be sent to a processor" unless purchasable.is_a?(Price)

          price_line(line_item, purchasable)
        end

        def price_line(line_item, price)
          return mirrored_line(line_item, price) if price.processor_price_id.present? && price.product.processor == processor
          raise Unmirrored, "price #{price.id} is not linked to #{processor}" if price.recurring?

          CheckoutLine.new(ref: line_item.id, quantity: line_item.quantity, price_data: inline_price(line_item, price))
        end

        def mirrored_line(line_item, price)
          CheckoutLine.new(ref: line_item.id, quantity: line_item.quantity, processor_price_id: price.processor_price_id,
                           recurring: price.recurring?)
        end

        def inline_price(line_item, price)
          InlinePrice.new(amount_cents: line_item.unit_amount_cents, currency: line_item.currency, interval: 'one_time', interval_count: 1,
                          name: price.purchasable_description, description: price.display_participant_summary.presence)
        end
      end
    end
  end
end
