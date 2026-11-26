# frozen_string_literal: true

module BetterTogether
  module Billing
    # A processor-side product, as an adapter reports it.
    ProductInfo = Data.define(:product_id, :name, :description, :active) do
      def initialize(product_id:, name: nil, description: nil, active: true)
        super
      end

      def active? = active ? true : false
    end
  end
end
