# frozen_string_literal: true

module BetterTogether
  module Billing
    # Resolves the current hosted community entitlement from the latest synced billing subscription.
    class HostedEntitlementResolver
      Result = Struct.new(
        :community,
        :billing_subscription,
        :hosted_status,
        :hosted_access_active,
        :hosted_access_level,
        :support_tier,
        :community_capacity_tier,
        keyword_init: true
      ) do
        def active?
          hosted_status == :active
        end

        def attention_needed?
          hosted_status == :attention
        end

        def inactive?
          hosted_status == :inactive
        end

        def status_label
          case hosted_status
          when :active
            I18n.t('better_together.billing.hosted_status_active', default: 'Hosted plan active')
          when :attention
            I18n.t('better_together.billing.hosted_status_attention', default: 'Billing attention needed')
          else
            I18n.t('better_together.billing.hosted_status_inactive', default: 'No active hosted plan')
          end
        end

        def status_badge_class
          case hosted_status
          when :active
            'text-bg-success'
          when :attention
            'text-bg-warning'
          else
            'text-bg-secondary'
          end
        end
      end

      def call(community:, billing_subscription: nil)
        subscription = billing_subscription || current_subscription_for(community)
        plan = subscription&.billing_plan

        Result.new(
          community: community,
          billing_subscription: subscription,
          hosted_status: hosted_status_for(subscription),
          hosted_access_active: subscription.present? && subscription.activeish?,
          hosted_access_level: plan&.hosted_access_level,
          support_tier: plan&.support_tier,
          community_capacity_tier: plan&.community_capacity_tier
        )
      end

      private

      def current_subscription_for(community)
        BetterTogether::Billing::Subscription.current_for_beneficiary(community)
      end

      def hosted_status_for(subscription)
        return :inactive if subscription.blank?
        return :attention if subscription.status == 'past_due'
        return :active if subscription.activeish?

        :inactive
      end
    end
  end
end
