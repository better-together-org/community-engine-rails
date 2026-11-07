# frozen_string_literal: true

module BetterTogether
  module Billing
    # Reminds payers of a renewal invoice that is still unpaid, a week and a day before the period ends, and
    # warns them a day before the grace runs out. Each stage is sent once however often this runs (the
    # notification's dedupe key names the period and the stage). A maintenance sweep: the only cross-tenant
    # read, acting on one record at a time.
    class RemindRenewalsJob < ApplicationJob
      STAGES = { 'week' => 7.days, 'day' => 1.day }.freeze
      GRACE_WARNING = 1.day

      def perform
        BetterTogether::Billing::SubscriptionTerm.local.select(:id).find_each { |row| remind(row.id) }
      end

      private

      def remind(term_id)
        term = BetterTogether::Billing::SubscriptionTerm.find(term_id)
        period = reminded_period(term)
        return unless period

        term.pay_subscription.status == 'past_due' ? warn_grace(term, period) : remind_stage(term, period)
      rescue StandardError => e
        Rails.logger.error("[billing] could not remind about #{term_id}: #{e.class}")
        BetterTogether.report_error(e, context: { job: self.class.name, term_id: })
      end

      # The unpaid invoice of a subscription that is still running, if there is one.
      def reminded_period(term)
        subscription = term.pay_subscription
        return if subscription.ends_at.present? || subscription.status == 'canceled'

        period = term.periods.unsettled.last
        period if period&.order&.open?
      end

      # The tightest stage that has been reached; earlier stages are not sent after it.
      def remind_stage(term, period)
        left = term.pay_subscription.current_period_end - Time.current
        stage = STAGES.select { |_, within| left <= within }.min_by { |_, within| within }&.first
        return unless stage

        BetterTogether::Billing::Notifications.deliver('renewal_reminder', subject: period, dedupe_key: "reminder:#{period.id}:#{stage}")
      end

      def warn_grace(term, period)
        return unless term.grace_ends_at && term.grace_ends_at - Time.current <= GRACE_WARNING

        BetterTogether::Billing::Notifications.deliver('grace_ending', subject: period, dedupe_key: "grace-ending:#{period.id}")
      end
    end
  end
end
