# frozen_string_literal: true

module BetterTogether
  module Billing
    module PayExtensions
      # Runs Pay's own background jobs (delivering a processor webhook, syncing a
      # customer) on the billing queue, with the rest of the billing work.
      #
      # Included into Pay::ApplicationJob, the base of Pay's jobs, so every Pay job
      # inherits the queue. Without this a webhook delivery would sit on `default`
      # behind unrelated work, defeating the dedicated billing queue.
      module BillingQueueRouting
        extend ActiveSupport::Concern

        included do
          queue_as BetterTogether::Billing::ApplicationJob::QUEUE_NAME

          # A webhook that matches no platform is reported by the dispatcher and its Pay
          # row is kept for replay; retrying it would only repeat the same refusal.
          discard_on BetterTogether::Billing::UnattributableWebhookError
        end
      end
    end
  end
end
