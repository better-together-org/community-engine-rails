# frozen_string_literal: true

module BetterTogether
  module Billing
    # Scans community subscriptions currently inside their app-owned grace
    # period and sends a one-time "billing needs attention" notice to the
    # community's managers, deduplicated via Subscription#grace_notice_sent?
    # so the notice fires exactly once per lapse, not on every scan.
    class NotifyHostedAccessGraceJob < BetterTogether::ApplicationJob
      COMMUNITY_MANAGER_ROLES = %w[community_manager community_administrator].freeze

      queue_as :maintenance

      def perform
        BetterTogether::Billing::Subscription.possibly_lapsed.includes(:pay_subscription).find_each do |subscription|
          next unless subscription.in_grace_period?
          next if subscription.grace_notice_sent?

          notify(subscription)
          subscription.record_grace_notice_sent!
        end
      end

      private

      def notify(subscription)
        community = subscription.beneficiary
        return unless community.is_a?(BetterTogether::Community)

        community_managers(community).each do |manager|
          BetterTogether::Billing::HostedAccessGraceNotifier.with(subscription:).deliver_later(manager)
        end
      end

      def community_managers(community)
        BetterTogether::PersonCommunityMembership
          .joins(:role)
          .includes(:member)
          .active
          .where(joinable: community)
          .where(better_together_roles: { identifier: COMMUNITY_MANAGER_ROLES })
          .map(&:member)
          .compact
      end
    end
  end
end
