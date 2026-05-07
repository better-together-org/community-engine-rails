# frozen_string_literal: true

module BetterTogether
  module Billing
    # Reconciles Stripe subscriptions for a single CE community.
    class StripeCommunityReconciliation
      Result = Struct.new(:community, :synced_count, :skipped_count, :subscription_ids, keyword_init: true)

      def call(community:)
        result = BetterTogether::Billing::StripeBillableOwnerReconciliation.new.call(billable_owner: community)
        Result.new(
          community:,
          synced_count: result.synced_count,
          skipped_count: result.skipped_count,
          subscription_ids: result.subscription_ids
        )
      end
    end
  end
end
