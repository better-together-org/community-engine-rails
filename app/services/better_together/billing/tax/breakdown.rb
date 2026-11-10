# frozen_string_literal: true

module BetterTogether
  module Billing
    module Tax
      # One tax as a buyer reads it: its label and rate, whether it is inside the price or added to it, and the amount
      # across everything bought. Built from calculator lines or an order's tax lines (anything with those four fields).
      Breakdown = Data.define(:label, :rate, :included, :amount_cents) do
        def self.from(lines)
          lines.group_by { |line| [line.label, line.rate, line.included] }.map do |(label, rate, included), grouped|
            new(label:, rate:, included:, amount_cents: grouped.sum(&:amount_cents))
          end
        end

        # "15%", "9.975%": the rate as a percentage without trailing zeros.
        def percent = "#{(BigDecimal(rate.to_s) * 100).round(3).to_s('F').sub(/\.?0+\z/, '')}%"
      end
    end
  end
end
