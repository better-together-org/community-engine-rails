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

          # Only mark as sent when someone was actually notified — a Person
          # beneficiary or a community with no manager/administrator would
          # otherwise be permanently (and silently) skipped, with no way to
          # ever warn them before hosted access pauses. Leaving the flag
          # unset lets the next daily scan retry.
          subscription.record_grace_notice_sent! if notify?(subscription)
        end
      end

      private

      def notify?(subscription)
        community = subscription.beneficiary
        return false unless community.is_a?(BetterTogether::Community)

        managers = community_managers(community)
        return false if managers.empty?

        managers.each do |manager|
          BetterTogether::Billing::HostedAccessGraceNotifier.with(subscription:).deliver_later(manager)
        end
        true
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
