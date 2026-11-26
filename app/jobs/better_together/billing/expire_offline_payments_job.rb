# frozen_string_literal: true

module BetterTogether
  module Billing
    # Closes offline payments whose hold ran out, by letting their order lapse (which gives back
    # what it held). If the order was closed some other way and its offline payment was left
    # waiting, the payment is closed to match. One payment at a time, so one bad row does not
    # stop the sweep. A maintenance sweep: the only cross-tenant read, and it acts on one record
    # at a time. A payment the seller can still confirm late is not lost: see
    # OfflinePayments::Transition.
    class ExpireOfflinePaymentsJob < ApplicationJob
      def perform
        BetterTogether::Billing::OfflinePayment.lapsed.select(:id).find_each { |row| expire(row.id) }
      end

      private

      def expire(offline_id)
        offline = BetterTogether::Billing::OfflinePayment.find(offline_id)
        return if BetterTogether::Billing::Orders::Expire.call(offline.order)

        BetterTogether::Billing::OfflinePayments::Transition.release(offline, 'expired') unless offline.reload.order.open?
      rescue StandardError => e
        Rails.logger.error("[billing] could not expire offline payment #{offline_id}: #{e.class}")
      end
    end
  end
end
