# frozen_string_literal: true

module BetterTogether
  module Billing
    # Lets orders whose payment window has passed lapse, releasing what they held. One order at
    # a time, each under its own lock, so one bad row does not stop the sweep and an order paid
    # meanwhile is left alone. A maintenance sweep: the only cross-tenant read, and it acts on
    # one record at a time.
    class ExpireOrdersJob < ApplicationJob
      def perform
        BetterTogether::Billing::Order.expired_holds.select(:id).find_each { |row| expire(row.id) }
      end

      private

      def expire(order_id)
        BetterTogether::Billing::Orders::Expire.call(BetterTogether::Billing::Order.find(order_id))
      rescue StandardError => e
        Rails.logger.error("[billing] could not expire order #{order_id}: #{e.class}")
      end
    end
  end
end
