# frozen_string_literal: true

module BetterTogether
  module Billing
    # One line of a checkout session, worked out by core from an order line. Either `processor_price_id` (a price the processor
    # already holds for this platform) or `price_data` (an InlinePrice, when it holds none) is set, never both. `ref` is the
    # order line's id, so a processor that reports line by line can be matched back.
    CheckoutLine = Data.define(:ref, :quantity, :processor_price_id, :price_data, :recurring) do
      def initialize(ref:, quantity:, processor_price_id: nil, price_data: nil, recurring: false)
        raise ArgumentError, 'a line has a processor price or inline price data, not both' if processor_price_id.present? && price_data

        raise ArgumentError, 'a line needs a processor price or inline price data' if processor_price_id.blank? && price_data.nil?

        super
      end

      def inline? = price_data.present?
      def recurring? = recurring ? true : false
    end
  end
end
