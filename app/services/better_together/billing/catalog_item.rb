# frozen_string_literal: true

module BetterTogether
  module Billing
    # What core asks a processor to hold: one product and all of its prices (Stripe's product with many prices). Built from a
    # Product (a plan is one) with its prices. Text is in the platform's own language.
    #
    # `processor_product_id` is set once the processor has the product. Prices already on the processor carry their id, so an
    # adapter creates only the ones that have none and archives nothing core still sells.
    CatalogItem = Data.define(:ref, :kind, :name, :description, :active, :tax_code, :processor_product_id, :prices) do
      def self.for(record)
        raise ArgumentError, "#{record.class} is not something a processor holds" unless record.is_a?(Product)

        for_product(record)
      end

      def self.for_product(product) # rubocop:disable Metrics/AbcSize
        prices = product.prices.map do |price|
          CatalogPrice.new(ref: price.id, amount_cents: price.amount_cents, currency: price.currency,
                           interval: price.billing_interval, interval_count: price.interval_count,
                           active: price.purchasable?, processor_price_id: price.processor_price_id.presence, lookup_key: nil)
        end
        new(ref: product.id, kind: product.is_a?(Plan) ? 'plan' : 'product', name: product.name, description: product.description,
            active: product.active, tax_code: product.tax_category&.identifier,
            processor_product_id: product.processor_product_id.presence, prices:)
      end
    end
  end
end
