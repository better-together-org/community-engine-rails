# frozen_string_literal: true

module BetterTogether
  module Billing
    # Marks a model as something a line item can be for (a plan, later a ticket type). The
    # opt-in is the registry: a line item only accepts purchasable types registered here, so
    # a type name is never resolved from a string.
    #
    # A purchasable describes itself for the line (what it is called, what it costs now, in
    # which currency), and may hold something back while an order waits to be paid:
    # `reserve!` when an order is placed and `release!` when it is cancelled or expires. A
    # plan holds nothing; a ticket type will hold a place.
    #
    # The order engine asks a purchasable what it is and what to do, and never tests its class: whether it renews
    # (`renews?`), is an extra on another purchase (`extra?`), is sold on a plan order (`plan_line?`), is given through
    # its own order (`fulfilled_by_order?`), and whether a person holds it (`held_by?`). Each default is the plain
    # one-off answer, so a new kind of purchasable overrides only what is different about it.
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
      # The same, in one language and with no fallback (nothing when it has no text in that language), so a line item can keep
      # the description of every language it has. Defaults to the current-language description for a plain-string purchasable.
      def purchasable_description_in(locale) = locale.to_sym == I18n.locale ? purchasable_description : nil

      def purchasable_amount_cents = raise(NotImplementedError, "#{self.class}#purchasable_amount_cents")
      def purchasable_currency = raise(NotImplementedError, "#{self.class}#purchasable_currency")

      # The tax category it is sold under; none means standard (taxed).
      def purchasable_tax_category = nil

      # Whether it can be bought right now.
      def purchasable? = true

      # Whether buying it starts a subscription that renews. The purpose of the order follows from this.
      def renews? = false

      # Whether it is only an extra sold with, or later on top of, another purchase and never the main thing bought.
      def extra? = false

      # Whether it belongs on an order that is read as a plan order (a plan, or an add-on to one).
      def plan_line? = false

      # Whether paying for it gives what it includes through the order itself (not through a subscription), taken
      # away again if the order is refunded or cancelled.
      def fulfilled_by_order? = false

      # Whether `person` holds it now: a live purchase of it that still stands. Nothing is held by default.
      def held_by?(_person) = false

      # Hold `quantity` for an order; raise to refuse. Nothing by default.
      def reserve!(quantity: 1); end

      # Give back what `reserve!` held.
      def release!(quantity: 1); end
    end
  end
end
