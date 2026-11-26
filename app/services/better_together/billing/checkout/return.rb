# frozen_string_literal: true

module BetterTogether
  module Billing
    module Checkout
      # The buyer comes back from the processor's checkout with a session id in the address.
      #
      # That id is only believed if it is the session WE sent this buyer to for THIS order: it is
      # matched against the payment's `processor_session_reference`. (Pay's own sync, `Pay.sync`,
      # accepts any session id.) The adapter then syncs the processor's state, which is optimistic and
      # idempotent; the webhook stays the authority on whether the payment succeeded.
      class Return
        class Unrecognised < StandardError; end

        def self.call(...) = new(...).call

        def initialize(order:, session_id:)
          @order = order
          @session_id = session_id.to_s
        end

        # The processor's reported status (`paid`, `unpaid`...) or nil.
        def call
          payment = order.payments.find_by(processor_session_reference: session_id) if session_id.present?
          raise Unrecognised, 'that checkout is not for this order' unless payment

          sync(payment)
        end

        private

        attr_reader :order, :session_id

        def sync(payment)
          adapter = Billing.processor_adapter(payment.processor)
          context = Configuration.context_for(order.platform, payment.processor)
          return unless adapter&.supports?(:checkout) && context

          adapter.sync_checkout_session(context:, checkout_session_id: session_id)&.[](:status)
        end
      end
    end
  end
end
