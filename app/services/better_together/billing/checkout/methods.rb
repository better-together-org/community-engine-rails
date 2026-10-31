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
      class Methods
        Choice = Data.define(:name, :available, :reason) do
          alias_method :available?, :available
        end

        def self.call(...) = new(...).call

        def initialize(platform:, plan:)
          @platform = platform
          @plan = plan
        end

        def call = plan.payment_methods.map { |name| choice(name) }

        # What the purchase is for: a plan that renews is a subscription.
        def purpose = plan.recurring? ? 'subscription' : 'one_time'

        private

        attr_reader :platform, :plan

        def choice(name)
          reason = reason_unavailable(name)
          Choice.new(name:, available: reason.nil?, reason:)
        end

        def reason_unavailable(name)
          return :not_enabled unless Configuration.context_for(platform, name)
          return :purpose_not_allowed unless purpose_allowed?(name)

          :currency_not_supported unless currency_supported?(name)
        end

        def purpose_allowed?(name)
          return true unless Billing.offline_method?(name)

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
