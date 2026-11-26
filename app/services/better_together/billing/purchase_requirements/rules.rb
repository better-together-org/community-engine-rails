# frozen_string_literal: true

module BetterTogether
  module Billing
    module PurchaseRequirements
      # The rules that apply to a dependent purchasable: the ones stored for it, or for its product when it is a price.
      class Rules
        def self.for(dependent) = new(dependent).call

        def initialize(dependent)
          @dependent = dependent
        end

        def call
          PurchaseRequirement.for_dependent(owner).to_a
        end

        private

        # A price is bound by the rules of its product, so a new price needs none of its own.
        def owner = dependent.is_a?(Price) ? dependent.product : dependent

        attr_reader :dependent
      end
    end
  end
end
