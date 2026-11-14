# frozen_string_literal: true

module BetterTogether
  module Billing
    module Checkout
      # The tax a buyer will be charged for a plan, shown at checkout before anything is placed. It runs the same
      # calculator Orders::Place runs, for the same place (the chosen billing address), so what is shown is what the order
      # carries. It writes nothing. Without an address there is no place yet: `known?` is false and no amount is promised.
      class TaxPreview
        attr_reader :plan, :add_ons

        def initialize(platform:, plan:, address:, add_ons: [])
          @platform = platform
          @plan = plan
          @add_ons = Array(add_ons)
          @address = address
        end

        # The plan and each add-on, in the order they are listed.
        def purchasables = [@plan, *@add_ons]

        def known? = @address.present?

        def tax_cents = result&.tax_cents.to_i

        def added_cents = result&.additional_cents.to_i

        def taxed? = result&.taxed? || false

        def total_cents = purchasables.sum(&:amount_cents) + added_cents

        # Every tax on the plan, as the calculator worked it out.
        def tax_lines = result ? result.lines : []

        # The taxes on one of the purchasables, by its place in `purchasables`.
        def tax_lines_for(index) = result ? result.lines_for(index) : []

        def summary = Orders::Summary.for_preview(self)

        private

        def result
          return unless known?

          @result ||= Tax::Calculator.for_lines(purchasables.map { |purchasable| { purchasable: } }, platform: @platform, **place)
        end

        def place = Orders::BillingAddressSnapshot.new(@address).tax_address
      end
    end
  end
end
