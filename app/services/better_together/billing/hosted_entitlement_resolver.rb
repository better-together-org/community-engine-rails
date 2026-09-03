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
        :grace_period_ends_at,
        keyword_init: true
      ) do
        def active?
          hosted_status == :active
        end

        def attention_needed?
          hosted_status == :attention
        end

        def grace_period?
          hosted_status == :grace
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
          when :grace
            I18n.t('better_together.billing.hosted_status_grace', default: 'Billing lapsed — grace period')
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
          when :grace
            'text-bg-danger'
          else
            'text-bg-secondary'
          end
        end
      end

      def call(community:, billing_subscription: nil)
        subscription = billing_subscription || current_subscription_for(community)
        plan = subscription&.billing_plan
        status = hosted_status_for(subscription)

        Result.new(
          community: community,
          billing_subscription: subscription,
          hosted_status: status,
          hosted_access_active: hosted_access_active?(subscription),
          hosted_access_level: plan&.hosted_access_level,
          support_tier: plan&.support_tier,
          community_capacity_tier: plan&.community_capacity_tier,
          grace_period_ends_at: subscription&.grace_period_expires_at
        )
      end

      private

      def current_subscription_for(community)
        BetterTogether::Billing::Subscription.current_for_owner(community)
      end

      # Stripe's own dunning/retry cycle is already covered by :attention
      # ('past_due', still activeish? — access stays on). :grace is the
      # BTS-owned second buffer that applies once Stripe's retries are
      # exhausted and the subscription has genuinely lapsed, per
      # Subscription#in_grace_period?.
      def hosted_status_for(subscription)
        return :inactive if subscription.blank?
        return :attention if subscription.status == 'past_due'
        return :active if subscription.activeish?
        return :grace if subscription.in_grace_period?

        :inactive
      end

      def hosted_access_active?(subscription)
        return false if subscription.blank?

        subscription.access_active?
      end
    end
  end
end
