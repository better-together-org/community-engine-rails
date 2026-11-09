# frozen_string_literal: true

module BetterTogether
  module Billing
    # Deletes Pay webhook rows that are still waiting after the payload retention window.
    #
    # Pay deletes a `pay_webhooks` row as soon as its event is processed
    # (`Pay::Webhook#process!`), so only deliveries that failed, were refused (for
    # example an unattributable webhook) or were never run linger. The row holds the raw
    # processor event, encrypted, so it is kept only as long as an operator could still
    # replay it, the same window as the event log's payloads.
    #
    # A row is never pruned sooner than Sidekiq keeps retrying the delivery job that holds it
    # (about 21 days): a retry that finds its row gone fails with a deserialization error and
    # the delivery is lost. A shorter configured retention is raised to that floor.
    class PruneStalePayWebhooksJob < ApplicationJob
      # Sidekiq's default retry schedule (25 attempts) spans about 21 days; one more day of margin.
      # If the retry policy for Pay's delivery jobs changes, change this with it.
      SIDEKIQ_RETRY_HORIZON_DAYS = 21
      MINIMUM_RETENTION_DAYS = SIDEKIQ_RETRY_HORIZON_DAYS + 1

      def perform
        days = [BetterTogether::Billing::Event.payload_retention_days, MINIMUM_RETENTION_DAYS].max
        cutoff = days.days.ago

        Pay::Webhook.where(Pay::Webhook.arel_table[:created_at].lt(cutoff)).in_batches(of: 100).delete_all
      end
    end
  end
end
