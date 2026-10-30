# frozen_string_literal: true

module BetterTogether
  module Billing
    # Marks a model as something an order line can be for (a plan, later a ticket type). The
    # opt-in is the registry: an order line only accepts purchasable types registered here, so
    # a type name is never resolved from a string.
    #
    # A purchasable describes itself for the line (what it is called, what it costs now, in
    # which currency), and may hold something back while an order waits to be paid:
    # `reserve!` when an order is placed and `release!` when it is cancelled or expires. A
    # plan holds nothing; a ticket type will hold a place.
    module Purchasable
      extend ActiveSupport::Concern

      included do
        Purchasable.model_names << name if name.present?
      end

      # Class names, not constants, so code reloading never holds stale classes.
      def self.model_names
        @model_names ||= Concurrent::Set.new
      end

      def purchasable_description = raise(NotImplementedError, "#{self.class}#purchasable_description")
      def purchasable_amount_cents = raise(NotImplementedError, "#{self.class}#purchasable_amount_cents")
      def purchasable_currency = raise(NotImplementedError, "#{self.class}#purchasable_currency")

      # Whether it can be bought right now.
      def purchasable? = true

      # Hold `quantity` for an order; raise to refuse. Nothing by default.
      def reserve!(quantity: 1); end

      # Give back what `reserve!` held.
      def release!(quantity: 1); end
    end
  end
end
