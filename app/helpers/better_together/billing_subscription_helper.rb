# frozen_string_literal: true

module BetterTogether
  # View helpers for subscriptions Community Engine renews.
  module BillingSubscriptionHelper
    SUBSCRIPTION_BADGES = {
      'active' => 'bg-success', 'past_due' => 'bg-warning text-dark', 'unpaid' => 'bg-danger', 'canceled' => 'bg-secondary',
      'ending' => 'bg-info text-dark'
    }.freeze
    PERIOD_BADGES = {
      'pending' => 'bg-warning text-dark', 'needs_agreement' => 'bg-info text-dark', 'blocked' => 'bg-danger', 'paid' => 'bg-success',
      'waived' => 'bg-success', 'lapsed' => 'bg-dark'
    }.freeze

    # The subscription's state in words people use: running, ending (cancelled at the end of the period), past due, lapsed, ended.
    def billing_subscription_state(subscription)
      return 'ending' if subscription.status == 'active' && subscription.ends_at.present?

      subscription.status
    end

    def billing_subscription_status_badge(subscription)
      state = billing_subscription_state(subscription)
      tag.span(t("better_together.billing.subscriptions.state_#{state}", default: state.humanize),
               class: "badge #{SUBSCRIPTION_BADGES.fetch(state, 'bg-secondary')} subscription-status-badge")
    end

    def billing_period_status_badge(period)
      tag.span(t("better_together.billing.subscriptions.period_#{period.status}"),
               class: "badge #{PERIOD_BADGES.fetch(period.status, 'bg-secondary')} period-status-badge")
    end

    def billing_period_range(period)
      "#{l(period.starts_at.to_date, format: :long)} – #{l(period.ends_at.to_date, format: :long)}"
    end

    # Cancel and resume are for a subscription that is running; a lapsed or ended one is paid for again instead.
    def billing_subscription_cancelable?(subscription) = subscription.status == 'active' && subscription.ends_at.blank?

    def billing_subscription_resumable?(subscription)
      subscription.status == 'active' && subscription.ends_at.present? && subscription.ends_at > Time.current
    end
  end
end
