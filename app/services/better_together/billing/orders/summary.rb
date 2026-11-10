# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # What an order says about money, in one shape for every place it is shown: the order and sale pages, checkout,
      # offline payment instructions, notice emails (HTML and text). They all read this, so the figures, the rows and
      # their order cannot differ from one surface to the next.
      #
      #   Orders::Summary.for_order(order)           # a placed order
      #   Orders::Summary.for_preview(tax_preview)   # a plan about to be bought
      #
      # Lines say whether tax applies to them. There is one row per tax (a label, a rate, whether it is inside the
      # price), with the amount it applies to and the tax itself; HST is one row, never split. The registration
      # numbers are those of whoever collected each tax.
      class Summary
        Line = Data.define(:description, :quantity, :amount_cents, :taxed)
        Item = Data.define(:description, :quantity, :amount_cents, :tax_lines)
        Registration = Data.define(:labels, :number)

        TaxRow = Data.define(:label, :rate, :included, :base_cents, :amount_cents) do
          # "15%", "9.975%": the rate as a percentage without trailing zeros.
          def percent = "#{(BigDecimal(rate.to_s) * 100).round(3).to_s('F').sub(/\.?0+\z/, '')}%"
        end

        attr_reader :currency, :lines, :tax_rows, :registrations, :total_cents, :subtotal_cents

        def self.for_order(order)
          items = order.line_items.map do |line|
            Item.new(description: line.description, quantity: line.quantity, amount_cents: line.total_cents, tax_lines: line.tax_lines.to_a)
          end
          new(currency: order.currency, items:, total_cents: order.total_cents)
        end

        def self.for_preview(preview)
          item = Item.new(description: preview.plan.purchasable_description, quantity: 1, amount_cents: preview.plan.amount_cents,
                          tax_lines: preview.tax_lines)
          new(currency: preview.plan.currency, items: [item], total_cents: preview.total_cents)
        end

        # `items` respond to description, quantity, amount_cents and tax_lines; a tax line responds to label, rate,
        # included, amount_cents and registration_number (an order's or a calculator's).
        def initialize(currency:, items:, total_cents:)
          @currency = currency
          @total_cents = total_cents
          @lines = items.map do |item|
            Line.new(description: item.description, quantity: item.quantity, amount_cents: item.amount_cents, taxed: item.tax_lines.any?)
          end
          @subtotal_cents = items.sum(&:amount_cents)
          @tax_rows = build_tax_rows(items)
          @registrations = build_registrations(items)
        end

        def taxed? = tax_rows.any?

        def tax_cents = tax_rows.sum(&:amount_cents)

        # The tax that comes on top of the prices; tax inside the prices is already part of the subtotal.
        def added_tax_cents = tax_rows.reject(&:included).sum(&:amount_cents)

        private

        def build_tax_rows(items)
          pairs = items.flat_map { |item| item.tax_lines.map { |line| [item, line] } }
          grouped = pairs.group_by { |_item, line| [line.label, line.rate, line.included] }
          grouped.map do |(label, rate, included), pairs|
            TaxRow.new(label:, rate:, included:, base_cents: base_of(pairs), amount_cents: pairs.sum { |_item, line| line.amount_cents })
          end
        end

        # What the tax applies to: each taxed item's price with any tax inside it taken out, counted once per item.
        def base_of(pairs)
          pairs.map(&:first).uniq.sum { |item| item.amount_cents - item.tax_lines.select(&:included).sum(&:amount_cents) }
        end

        def build_registrations(items)
          with_number = items.flat_map(&:tax_lines).select { |line| line.registration_number.present? }
          with_number.group_by(&:registration_number).map do |number, lines|
            Registration.new(labels: lines.map(&:label).uniq, number:)
          end
        end
      end
    end
  end
end
