# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # Copies the tax worked out for an order (see Tax::Calculator) onto the unsaved order, its line items and a tax
      # line for each tax, so the tax stays as it was charged even if rates change later.
      class ApplyTax
        def self.call(...) = new(...).call

        def initialize(order, tax)
          @order = order
          @tax = tax
        end

        def call
          return order unless tax.taxed?

          order.assign_attributes(order_attributes)
          order.line_items.each_with_index { |line_item, index| apply_to(line_item, tax.lines_for(index)) }
          order
        end

        private

        attr_reader :order, :tax

        def order_attributes
          { tax_registration: tax.registration, tax_country_iso: tax.country_iso, tax_region_code: tax.region_code,
            tax_settlement: tax.settlement,
            prices_include_tax: tax.prices_include_tax, tax_cents: tax.tax_cents, included_tax_cents: tax.included_cents }
        end

        def apply_to(line_item, lines)
          line_item.assign_attributes(tax_category: line_item.purchasable.purchasable_tax_category, tax_cents: lines.sum(&:amount_cents),
                                      included_tax_cents: lines.select(&:included).sum(&:amount_cents))
          lines.each do |line|
            built = line_item.tax_lines.build(**tax_line_attributes(line))
            built.snapshot_translations(:label) { |locale| line.tax_rate.label(locale:, fallback: false) }
          end
        end

        def tax_line_attributes(line)
          { platform_id: order.platform_id, order:, tax_rate: line.tax_rate, rate: line.rate,
            amount_cents: line.amount_cents, included: line.included, registration_number: line.registration_number,
            authority: line.authority }
        end
      end
    end
  end
end
