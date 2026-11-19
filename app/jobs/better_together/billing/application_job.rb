# frozen_string_literal: true

module BetterTogether
  module Billing
    # Base class for every billing background job.
    #
    # Payment work runs on its own `billing` queue so it is never stuck behind
    # maintenance, metrics or federation jobs. ActiveJob applies the host's
    # `queue_name_prefix`, so a host that sets one runs `<prefix>_billing`. The
    # queue must be listed (with a high weight, and ideally a dedicated capsule)
    # in the host's Sidekiq configuration; see docs/production/billing_queue_rollout.md.
    class ApplicationJob < BetterTogether::ApplicationJob
      QUEUE_NAME = :billing

      queue_as QUEUE_NAME
    end
  end
end
