# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # A steward gives a subscription that is past due more days before it lapses. If it had already lapsed
      # and the new date is still ahead, it is running again (past due) until then.
      class ExtendGrace
        class Refused < StandardError; end

        MAX_DAYS = 90

        def self.call(...) = new(...).call

        def initialize(term:, days:, now: Time.current)
          @term = term
          @days = days.to_i
          @now = now
        end

        def call
          raise Refused, 'give between 1 and 90 days' unless days.between?(1, MAX_DAYS)

          term.with_lock do
            raise Refused, 'only a subscription that has gone unpaid can be given more time' unless unpaid_or_late?

            give_time
            term
          end
        end

        private

        attr_reader :term, :days, :now

        def subscription = term.pay_subscription

        def give_time
          term.update!(grace_ends_at: [term.grace_ends_at, now].max + days.days)
          reinstate
        end

        def unpaid_or_late? = term.local? && %w[past_due unpaid].include?(subscription.status) && term.grace_ends_at.present?

        def reinstate
          return unless subscription.status == 'unpaid'

          subscription.update!(status: :past_due, ends_at: nil)
          term.latest_period&.update!(status: 'pending') if term.latest_period&.status == 'lapsed'
        end
      end
    end
  end
end
