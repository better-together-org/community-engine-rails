# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # Undoes a cancellation at the end of the period, while that period still runs (Pay's `resume`). A
      # subscription that has already ended or lapsed cannot be resumed; it is paid for again.
      class Resume
        class Refused < StandardError; end

        def self.call(term:) = new(term).call

        def initialize(term)
          @term = term
        end

        def call
          term.with_lock do
            raise Refused, 'that subscription cannot be resumed' unless subscription.resumable?

            subscription.resume
            subscription
          end
        end

        private

        attr_reader :term

        def subscription = term.pay_subscription
      end
    end
  end
end
