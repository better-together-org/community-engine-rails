# frozen_string_literal: true

module BetterTogether
  module Billing
    # Gives what a paid one-time plan includes, and takes it away if the order is refunded (see
    # Entitlements::Sync). Run after the order changed, as a retryable job. Safe to repeat.
    class SyncOrderEntitlementJob < ApplicationJob
      retry_on Entitlements::Sync::Incomplete, wait: :polynomially_longer, attempts: 5

      def perform(order)
        Entitlements::Sync.order(order)
      end
    end
  end
end
