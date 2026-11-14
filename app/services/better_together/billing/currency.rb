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

      # The largest price a form accepts, in minor units (the column is a bigint).
      MAX_MINOR = 99_999_999_999

      # What a person typed as a price ("45", "45.00", "45,50") as [minor units, nil], or [nil, reason] where the reason
      # is :blank, :not_an_amount, :too_precise (more decimals than the currency has) or :too_large.
      def parse_major(text, code)
        text = text.to_s.strip
        return [nil, :blank] if text.empty?

        text = text.tr(',', '.') if text.count(',') == 1 && text.exclude?('.')
        return [nil, :not_an_amount] unless text.match?(/\A\d+(\.\d+)?\z/)

        scaled = BigDecimal(text) * (10**exponent(code))
        return [nil, :too_precise] unless scaled == scaled.round
        return [nil, :too_large] if scaled > MAX_MINOR

        [scaled.to_i, nil]
      end

      # A stored price as it is typed into a form: "45.00", or "4500" for a currency with no cents.
      def to_input(amount_minor, code)
        format("%.#{exponent(code)}f", to_major(amount_minor, code))
      end

      def unit(code)
        return '' if code.blank?

        SYMBOLS.fetch(code.to_s.upcase, "#{code.to_s.upcase} ")
      end
    end
  end
end
