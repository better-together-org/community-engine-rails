# frozen_string_literal: true

module BetterTogether
  module Billing
    # Makes the invoice for the next period of every subscription Community Engine renews, once it is within
    # the plan's lead days of the period ending. A subscription whose invoice could not be made (agreements to
    # accept again, a method switched off) is tried again each run. One subscription at a time, so one bad
    # row does not stop the sweep. A maintenance sweep: the only cross-tenant read, acting on one record at a
    # time. Safe to repeat: see Subscriptions::GenerateRenewal.
    class GenerateRenewalsJob < ApplicationJob
      def perform
        BetterTogether::Billing::SubscriptionTerm.local.select(:id).find_each { |row| generate(row.id) }
      end

      private

      def generate(term_id)
        Subscriptions::GenerateRenewal.call(term: BetterTogether::Billing::SubscriptionTerm.find(term_id))
      rescue StandardError => e
        Rails.logger.error("[billing] could not generate a renewal for #{term_id}: #{e.class}")
        BetterTogether.report_error(e, context: { job: self.class.name, term_id: })
      end
    end
  end
end
