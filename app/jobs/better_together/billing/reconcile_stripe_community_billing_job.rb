# frozen_string_literal: true

module BetterTogether
  module Billing
    # Reconciles Stripe subscriptions for a single community's billable customer.
    class ReconcileStripeCommunityBillingJob < BetterTogether::ApplicationJob
      queue_as :default

      retry_on StandardError, wait: :polynomially_longer, attempts: 10

      def perform(community_id)
        community = BetterTogether::Community.find_by(id: community_id)
        return unless community

        BetterTogether::Billing::ReconcileStripeBillableOwnerBillingJob.perform_later(community.class.name, community.id)
      end
    end
  end
end
