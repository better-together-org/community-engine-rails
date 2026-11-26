# frozen_string_literal: true

module BetterTogether
  module Billing
    # Takes back what depended on an order's lines once the order is refunded or cancelled, for rules that say `revoke`
    # (see PurchaseRequirements::RevokeDependents). Run after the order changed, as a retryable job. Safe to repeat.
    class RevokeDependentsJob < ApplicationJob
      def perform(order)
        PurchaseRequirements::RevokeDependents.call(order:)
      end
    end
  end
end
