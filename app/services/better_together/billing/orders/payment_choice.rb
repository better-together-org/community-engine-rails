# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # The way of paying an order was placed with, and whether it can be used for this order.
      #
      # * A method outside a vendor (cash, a cheque, an e-transfer) works only when the seller switched it on for
      #   this kind of purchase.
      # * A method through a processor works only when the platform has that processor configured and it can take
      #   a checkout.
      # * Either must work in the order's currency.
      #
      # No method named means the order is simply placed, to be paid however the buyer later chooses.
      class PaymentChoice
        def initialize(platform:, seller:, name:, purpose:, currency:)
          @platform = platform
          @seller = seller
          @name = name.presence&.to_s
          @purpose = purpose
          @currency = currency
        end

        # Why the method cannot be used, or nil when it can (or none was named).
        def problem
          return unless adapter

          return 'that way of paying is not available' unless available?

          'that way of paying does not work in that currency' if unsupported_currency?
        end

        # The switched-on setting, when the method is one outside a vendor.
        def offline_setting
          return unless offline?

          @offline_setting ||= sellers_settings.enabled.find_by(processor: name)
        end

        # The adapter, when the method is a processor that takes a checkout.
        def processor_adapter = (adapter if !offline? && adapter&.supports?(:checkout))

        private

        attr_reader :platform, :seller, :name, :purpose, :currency

        # An unknown name is not a problem here: nothing is opened for it.
        def adapter = (@adapter ||= (Billing.processor_adapter(name) if name))

        def offline? = adapter.present? && Billing.offline_method?(name)

        def available?
          offline? ? offline_setting&.allows?(purpose) : (processor_adapter.present? && Configuration.context_for(platform, name).present?)
        end

        def unsupported_currency?
          currencies = adapter.supported_currencies
          currencies.present? && currencies.exclude?(currency)
        end

        def sellers_settings
          seller ? platform.billing_processor_settings.sold_by(seller) : platform.billing_processor_settings.sold_by_platform
        end
      end
    end
  end
end
