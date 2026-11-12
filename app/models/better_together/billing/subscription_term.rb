# frozen_string_literal: true

module BetterTogether
  module Billing
    # What Community Engine knows about a subscription that Pay has no place for. The Pay subscription
    # (`Pay::Subscription`) stays the one subscription record: its status, current period, trial and end
    # are the truth, for a subscription renewed by Community Engine and one renewed by a processor alike.
    # This holds the plan it follows, who it is for, the method each renewal is paid by, the price it was
    # sold at, the anchor its periods are counted from, and when its unpaid grace ends.
    #
    # Reach it through its platform (`platform.billing_subscription_terms`).
    class SubscriptionTerm < ApplicationRecord
      include PlatformBound
      include Subjectable

      self.table_name = 'better_together_billing_subscription_terms'

      belongs_to :pay_subscription, class_name: 'Pay::Subscription', optional: false
      belongs_to :plan, class_name: 'BetterTogether::Billing::Plan', optional: false
      # The plan the subscriber chose to move to when the next period starts (see Subscriptions::ChangePlan).
      belongs_to :pending_plan, class_name: 'BetterTogether::Billing::Plan', optional: true
      belongs_to :beneficiary, polymorphic: true, optional: true
      has_many :periods, -> { order(:sequence) }, class_name: 'BetterTogether::Billing::SubscriptionPeriod', inverse_of: :term,
                                                  foreign_key: :subscription_term_id, dependent: :restrict_with_error

      attr_readonly :pay_subscription_id, :payment_method

      validates :payment_method, presence: true
      validates :currency, inclusion: { in: Plan::SUPPORTED_CURRENCY_CODES }
      validates :unit_amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :anchor_sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :pay_subscription_id, uniqueness: true
      validate :same_platform
      validate :plan_only_changes_through_the_service, on: :update
      validate :beneficiary_allowed

      scope :local, -> { joins(:pay_subscription).where(pay_subscriptions: { type: 'Pay::Local::Subscription' }) }

      # The person who pays: the owner of the Pay customer.
      def payer = pay_subscription.customer.owner

      # Who the subscription is for: the beneficiary, else the payer.
      def beneficiary_or_payer = beneficiary || payer

      def subscription = pay_subscription

      # Whether Community Engine renews it (a method outside a processor), rather than a processor.
      def local? = pay_subscription.is_a?(Pay::Local::Subscription)

      def latest_period = periods.last

      def time_zone = platform.time_zone.presence || 'UTC'

      def period_start(sequence) = Periods.starts_at(anchor: anchor_at, plan:, sequence:, time_zone:, anchor_sequence:)

      def period_end(sequence) = Periods.ends_at(anchor: anchor_at, plan:, sequence:, time_zone:, anchor_sequence:)

      # Days a period may stay unpaid before the subscription lapses.
      def grace_days = plan.grace_days

      private

      # The plan a subscription follows changes only through Subscriptions::ChangePlan, never by a stray update.
      def plan_only_changes_through_the_service
        errors.add(:plan_id, :readonly) if plan_id_changed? && !Thread.current[:billing_plan_change]
      end

      def same_platform
        errors.add(:platform, :platform_owner_mismatch) if plan && plan.platform_id != platform_id
        errors.add(:pay_subscription, :platform_owner_mismatch) if pay_subscription && pay_subscription.platform_id != platform_id
      end

      def beneficiary_allowed
        return if beneficiary_type.blank?

        errors.add(:beneficiary_type, :inclusion) unless SellerScoped.assignable_types.include?(beneficiary_type)
      end
    end
  end
end
