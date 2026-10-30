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
    class PruneStalePayWebhooksJob < ApplicationJob
      def perform
        cutoff = BetterTogether::Billing::Event.payload_retention_days.days.ago

        Pay::Webhook.where(Pay::Webhook.arel_table[:created_at].lt(cutoff)).in_batches(of: 100).delete_all
      end
    end
  end
end
