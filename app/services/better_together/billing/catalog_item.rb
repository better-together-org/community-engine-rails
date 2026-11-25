# frozen_string_literal: true

module BetterTogether
  module Billing
    # What core asks a processor to hold: one product and all of its prices (Stripe's product with many prices). Built from a
    # Plan (one price, recurring or not) or a Product (its prices). Text is in the platform's own language.
    #
    # `processor_product_id` is set once the processor has the product. Prices already on the processor carry their id, so an
    # adapter creates only the ones that have none and archives nothing core still sells.
    CatalogItem = Data.define(:ref, :kind, :name, :description, :active, :tax_code, :processor_product_id, :prices) do
      def self.for(record)
        case record
        when Plan then for_plan(record)
        when Product then for_product(record)
        else raise ArgumentError, "#{record.class} is not something a processor holds"
        end
      end

      def self.for_plan(plan)
        price = CatalogPrice.new(ref: plan.id, amount_cents: plan.amount_cents, currency: plan.currency, interval: plan.billing_interval,
                                 interval_count: plan.interval_count || 1, active: plan.active,
                                 processor_price_id: plan.processor_price_id.presence, lookup_key: nil)
        new(ref: plan.id, kind: 'plan', name: plan.name, description: plan.description, active: plan.active, tax_code: nil,
            processor_product_id: plan.processor_product_id.presence, prices: [price])
      end

      def self.for_product(product) # rubocop:disable Metrics/AbcSize
        prices = product.prices.map do |price|
          CatalogPrice.new(ref: price.id, amount_cents: price.amount_cents, currency: price.currency, interval: 'one_time', interval_count: 1,
                           active: price.purchasable?, processor_price_id: price.processor_price_id.presence, lookup_key: nil)
        end
        new(ref: product.id, kind: 'product', name: product.name, description: product.description, active: product.active,
            tax_code: product.tax_category&.identifier, processor_product_id: product.processor_product_id.presence, prices:)
      end
    end
  end
end
