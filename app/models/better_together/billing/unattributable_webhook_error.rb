# frozen_string_literal: true

module BetterTogether
  module Billing
    # Raised when a processor webhook cannot be tied to exactly one platform that has
    # billing configured for that processor. Nothing is stored under any tenant: the
    # delivery stays in Pay's (encrypted) webhook table for an operator to replay once
    # the platform or account mapping is fixed. The message carries identifiers only,
    # never the payload.
    class UnattributableWebhookError < StandardError; end
  end
end
