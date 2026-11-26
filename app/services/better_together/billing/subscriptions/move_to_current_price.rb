# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # A plan's price change applies to new subscribers; this moves one existing subscriber to the plan's
      # price today, from their next invoice. (An invoice already made keeps the price it was made at.)
      module MoveToCurrentPrice
        class Refused < StandardError; end

        module_function

        def call(term:)
          plan = term.plan
          raise Refused, 'already at the current price' if term.unit_amount_cents == plan.amount_cents && term.currency == plan.currency

          term.update!(unit_amount_cents: plan.amount_cents, currency: plan.currency)
          term
        end
      end
    end
  end
end
