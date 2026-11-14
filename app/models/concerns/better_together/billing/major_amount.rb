# frozen_string_literal: true

module BetterTogether
  module Billing
    # Lets a form set a plan's price in major units (45.00) instead of cents. The figure is converted for the plan's
    # currency when the plan is validated, so it follows a currency chosen in the same request. A figure that cannot be
    # used is reported on the amount and the stored price is left as it was.
    module MajorAmount
      extend ActiveSupport::Concern

      included do
        before_validation :apply_major_amount
        validate :major_amount_is_usable
      end

      attr_reader :amount

      def amount=(text)
        @amount = text.to_s.strip
        @amount_error = nil
      end

      # What the amount field shows: what was typed (so a mistake can be fixed), else the stored price.
      def amount_field_value
        @amount.nil? ? Currency.to_input(amount_cents, currency) : @amount
      end

      private

      def apply_major_amount
        return if @amount.nil?

        cents, @amount_error = Currency.parse_major(@amount, currency)
        self.amount_cents = cents if cents
      end

      def major_amount_is_usable
        return unless @amount_error

        errors.add(:amount, @amount_error, places: Currency.exponent(currency))
      end
    end
  end
end
