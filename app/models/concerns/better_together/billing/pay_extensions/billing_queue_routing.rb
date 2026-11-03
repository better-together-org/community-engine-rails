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

          # Pay publishes a webhook to every subscriber and lets each finish. When two of them
          # fail, Rails raises ONE InstrumentationSubscriberError wrapping both, so the discard
          # above would not match and Sidekiq would retry the refusal for weeks. Discard when
          # any wrapped error is the refusal; anything else is re-raised to be retried.
          rescue_from ActiveSupport::Notifications::InstrumentationSubscriberError do |error|
            raise error unless error.exceptions.any?(BetterTogether::Billing::UnattributableWebhookError)

            Rails.logger.warn('[billing] discarded a webhook the dispatcher refused to attribute')
          end
        end
      end
    end
  end
end
