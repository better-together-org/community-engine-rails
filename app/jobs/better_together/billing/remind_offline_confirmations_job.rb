# frozen_string_literal: true

module BetterTogether
  module Billing
    # Nudges both sides of an offline payment that is still waiting:
    #
    # * the seller, once a day while it waits (after a day), that there is a payment to confirm or reject;
    # * the buyer, once, when their hold is about to run out and they have not said they paid.
    #
    # Neither reminder carries payment instructions. One payment at a time, so one bad row does
    # not stop the sweep; the notification receipts make a repeated run harmless.
    class RemindOfflineConfirmationsJob < ApplicationJob
      SELLER_AFTER = 24.hours
      BUYER_WITHIN = 24.hours

      def perform
        remind_sellers
        warn_buyers
      end

      private

      def offline_payments = BetterTogether::Billing::OfflinePayment

      def remind_sellers
        offline_payments.due_a_reminder(SELLER_AFTER).select(:id).find_each { |row| guarded(row.id) { |offline| remind(offline) } }
      end

      def warn_buyers
        soon = offline_payments.awaiting.where(expires_at: Time.current..BUYER_WITHIN.from_now)
        soon.select(:id).find_each { |row| guarded(row.id) { |offline| warn(offline) } }
      end

      def remind(offline)
        BetterTogether::Billing::Notifications.deliver('confirmation_reminder', subject: offline,
                                                                                dedupe_key: "reminder:#{offline.id}:#{Date.current}")
        offline.update_columns(last_reminded_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      end

      def warn(offline)
        BetterTogether::Billing::Notifications.deliver('hold_expiring', subject: offline, dedupe_key: "hold-expiring:#{offline.id}")
      end

      def guarded(offline_id)
        yield offline_payments.find(offline_id)
      rescue StandardError => e
        Rails.logger.error("[billing] could not remind about offline payment #{offline_id}: #{e.class}")
      end
    end
  end
end
