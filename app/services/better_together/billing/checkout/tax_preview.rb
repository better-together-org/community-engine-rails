# frozen_string_literal: true

module BetterTogether
  module Billing
    module Checkout
      # The tax a buyer will be charged for a plan, shown at checkout before anything is placed. It runs the same
      # calculator Orders::Place runs, for the same place (the chosen billing address), so what is shown is what the order
      # carries. It writes nothing. Without an address there is no place yet: `known?` is false and no amount is promised.
      class TaxPreview
        def initialize(platform:, plan:, address:)
          @platform = platform
          @plan = plan
          @address = address
        end

        def known? = @address.present?

        def tax_cents = result&.tax_cents.to_i

        def added_cents = result&.additional_cents.to_i

        def taxed? = result&.taxed? || false

        def total_cents = @plan.amount_cents + added_cents

        # One row per tax (label, rate, whether inside the price), amounts added up.
        def groups = result ? Tax::Breakdown.from(result.lines) : []

        private

        def result
          return unless known?

          @result ||= Tax::Calculator.for_lines([{ purchasable: @plan }], platform: @platform, **place)
        end

        def place = Orders::BillingAddressSnapshot.new(@address).tax_address
      end
    end
  end
end
