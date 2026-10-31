# frozen_string_literal: true

module BetterTogether
  module Billing
    # Minor-unit arithmetic and display for plan prices. Amounts are stored in the
    # currency's smallest unit; zero-decimal currencies (JPY, KRW) have no cents.
    module Currency
      ZERO_DECIMAL = %w[BIF CLP DJF GNF JPY KMF KRW MGA PYG RWF UGX VND VUV XAF XOF XPF].freeze
      SYMBOLS = { 'CAD' => 'CA$', 'USD' => 'US$', 'EUR' => '€', 'GBP' => '£' }.freeze

      module_function

      def exponent(code)
        ZERO_DECIMAL.include?(code.to_s.upcase) ? 0 : 2
      end

      def to_major(amount_minor, code)
        amount_minor.to_i / (10**exponent(code)).to_f
      end

      # Whole minor units from what a person typed ("12.50"), or nil when it is not a plain amount.
      def to_minor(text, code)
        text = text.to_s.strip
        return unless text.match?(/\A\d+(\.\d+)?\z/)

        (BigDecimal(text) * (10**exponent(code))).round.to_i
      end

      def unit(code)
        return '' if code.blank?

        SYMBOLS.fetch(code.to_s.upcase, "#{code.to_s.upcase} ")
      end
    end
  end
end
