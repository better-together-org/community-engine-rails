# frozen_string_literal: true

module BetterTogether
  module Billing
    module Checkout
      # The ways a buyer can pay for a plan, and for each why it is not available when it is not.
      #
      # A plan accepts some methods (its online processor, and the others it lists); a method is
      # offered only if it is also switched on for the platform, allowed for this kind of
      # purchase, and works in the plan's currency. An unavailable method is still listed, with
      # the reason, so the buyer is never left wondering where an option went.
      #
      # Store credit is offered when the buyer (when known) has any of it, unexpired and allowed for this kind of
      # purchase. It need not cover the plan: credit is one part of a payment among others, so the choice carries
      # `cap_cents`, the most the buyer can spend, for the screen to show and bound the amount.
      class Methods
        Choice = Data.define(:name, :available, :reason, :cap_cents) do
          alias_method :available?, :available

          # Whether a subscription can be renewed by this way: one Community Engine settles itself, and in use. Store
          # credit counts even when the buyer has none today, because what matters is the balance when a renewal falls due.
          def renewable? = Billing.local_method?(name) && (available? || reason == :insufficient_credit)
        end

        def self.call(...) = new(...).call

        # `add_ons:` are extras on the same order: it can be paid only by a way every one of them accepts.
        def initialize(platform:, plan:, buyer: nil, add_ons: [])
          @platform = platform
          @plan = plan
          @buyer = buyer
          @add_ons = Array(add_ons)
        end

        def call = accepted_names.map { |name| choice(name) }

        # What the purchase is for: a plan that renews is a subscription.
        def purpose = plan.recurring? ? 'subscription' : 'one_time'

        private

        attr_reader :platform, :plan, :buyer, :add_ons

        # With add-ons the order can be paid only by a way every plan on it accepts and Community Engine settles itself: an online
        # processor prices an order from its own price ids, and an add-on has none.
        def accepted_names
          names = add_ons.reduce(plan.payment_methods) { |accepted, add_on| accepted & add_on.payment_methods }
          add_ons.any? || plan.add_on? ? names.select { |name| Billing.local_method?(name) } : names
        end

        def choice(name)
          reason = reason_unavailable(name)
          Choice.new(name:, available: reason.nil?, reason:, cap_cents: credit_cap(name))
        end

        def reason_unavailable(name)
          return :not_enabled unless Configuration.context_for(platform, name)
          return :purpose_not_allowed unless purpose_allowed?(name)
          return :currency_not_supported unless currency_supported?(name)

          :insufficient_credit unless credit_covers?(name)
        end

        # Anything but store credit is always covered; credit needs something to spend.
        def credit_covers?(name) = credit_cap(name).nil? || credit_cap(name).positive?

        # What the buyer can spend as credit, or nil for a way of paying that has no such limit (or no known buyer).
        def credit_cap(name)
          return unless Billing.internal_method?(name) && buyer

          Credit.usable_cents(platform:, holder: buyer, currency: plan.currency, purpose:)
        end

        def purpose_allowed?(name)
          return true unless Billing.local_method?(name)

          platform.billing_processor_settings.sold_by_platform.find_by(processor: name)&.allows?(purpose)
        end

        def currency_supported?(name)
          currencies = Billing.processor_adapter(name)&.supported_currencies
          currencies.nil? || currencies.include?(plan.currency)
        end
      end
    end
  end
end
