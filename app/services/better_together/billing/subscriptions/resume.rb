# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # Undoes a cancellation at the end of the period, while that period still runs (Pay's `resume`), and brings back the
      # renewal the cancellation had lapsed. A
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
            reopen_renewal
            subscription
          end
        end

        private

        attr_reader :term

        def subscription = term.pay_subscription

        # Cancelling lapsed the renewal that had not been paid (and cancelled its invoice). That period is still ahead,
        # so take it back out and the renewal for it is issued again on schedule, rather than skipped.
        def reopen_renewal
          last = term.periods.last
          return unless last&.status == 'lapsed' && last.starts_at >= Time.current && last.order&.paid_cents.to_i.zero?

          last.destroy!
        end
      end
    end
  end
end
