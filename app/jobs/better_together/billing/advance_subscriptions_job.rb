# frozen_string_literal: true

module BetterTogether
  module Billing
    # Moves subscriptions Community Engine renews through their time-based states: active to past due when a
    # period ends unpaid, past due to unpaid when the grace ends, a cancellation to canceled when its date
    # arrives (see Subscriptions::Advance). It also tries once more to pay a renewal invoice from store credit
    # when the payer's credit may have been topped up. One subscription at a time. A maintenance sweep: the
    # only cross-tenant read, acting on one record at a time. Safe to repeat.
    class AdvanceSubscriptionsJob < ApplicationJob
      def perform
        BetterTogether::Billing::SubscriptionTerm.local.select(:id).find_each { |row| advance(row.id) }
      end

      private

      def advance(term_id)
        term = BetterTogether::Billing::SubscriptionTerm.find(term_id)
        Subscriptions::Advance.call(term:)
        retry_credit(term)
      rescue StandardError => e
        Rails.logger.error("[billing] could not advance subscription #{term_id}: #{e.class}")
        BetterTogether.report_error(e, context: { job: self.class.name, term_id: })
      end

      def retry_credit(term)
        return unless BetterTogether::Billing.internal_method?(term.payment_method)

        period = term.periods.unsettled.last
        Subscriptions::PayWithCredit.call(period:) if period&.order
      end
    end
  end
end
