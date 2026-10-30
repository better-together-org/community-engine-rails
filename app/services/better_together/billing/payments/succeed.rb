# frozen_string_literal: true

module BetterTogether
  module Billing
    module Payments
      # Marks a payment as paid and settles its order. Safe to repeat: a payment that already
      # succeeded is returned as it is.
      class Succeed
        def self.call(...) = new(...).call

        def initialize(payment, reference: nil)
          @payment = payment
          @reference = reference
        end

        def call
          payment.with_lock do
            if payment.pending?
              payment.update!(status: 'succeeded', paid_at: Time.current,
                              processor_reference: reference.presence || payment.processor_reference)
            end
          end
          Orders::Settle.call(payment.order)
          payment
        end

        private

        attr_reader :payment, :reference
      end
    end
  end
end
