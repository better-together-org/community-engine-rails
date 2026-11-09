# frozen_string_literal: true

module BetterTogether
  module Billing
    module Payments
      # Lets go of a payment that will not be made: the order was cancelled or lapsed, or the buyer left
      # a checkout. Different from failing it (the processor declined): a cancelled payment was never
      # attempted to the end. For a payment through a processor, the processor is told too (the
      # checkout session is expired or the intent cancelled), after the change is saved, and a
      # processor that cannot be reached is logged and does not stop the order being let go.
      #
      # Money can still arrive for a cancelled payment (a card charged just as the session was
      # expired): Payments::Succeed handles that, the processor being the authority.
      class Cancel
        def self.call(...) = new(...).call

        def initialize(payment, failure_code: nil)
          @payment = payment
          @failure_code = failure_code
        end

        def call
          cancelled = payment.with_lock do
            next false unless payment.in_flight?

            payment.update!(status: 'cancelled', failure_code:)
            true
          end
          ActiveRecord.after_all_transactions_commit { release_at_processor } if cancelled && payment.remote?
          payment
        end

        private

        attr_reader :payment, :failure_code

        def release_at_processor
          adapter = Billing.processor_adapter(payment.processor)
          context = Configuration.context_for(payment.platform, payment.processor)
          adapter.release_payment(context:, payment:, idempotency_key: "release:#{payment.id}") if adapter&.supports?(:checkout) && context
        rescue StandardError => e
          report(e)
        end

        def report(error)
          Rails.logger.error("[billing] could not release payment #{payment.id} at the processor: #{error.class}")
          BetterTogether.report_error(error, context: { payment: payment.id })
        end
      end
    end
  end
end
