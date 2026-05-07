# frozen_string_literal: true

module BetterTogether
  module Billing
    # Local subscription record synced from the payment processor.
    class Subscription < ApplicationRecord
      self.table_name = 'better_together_billing_subscriptions'

      PROCESSORS = %w[stripe].freeze
      STATUSES = %w[
        incomplete
        trialing
        active
        past_due
        canceled
        unpaid
        paused
      ].freeze

      belongs_to :community,
                 class_name: 'BetterTogether::Community',
                 inverse_of: :billing_subscriptions
      belongs_to :billing_plan,
                 class_name: 'BetterTogether::Billing::Plan',
                 inverse_of: :subscriptions

      has_many :billing_events,
               class_name: 'BetterTogether::Billing::Event',
               foreign_key: :billing_subscription_id,
               dependent: :nullify,
               inverse_of: :billing_subscription

      validates :processor, inclusion: { in: PROCESSORS }
      validates :status, inclusion: { in: STATUSES }
      validates :processor_subscription_id, presence: true, uniqueness: true
      validates :community, :billing_plan, presence: true
      validates :cancel_at_period_end, inclusion: { in: [true, false] }

      scope :activeish, -> { where(status: %w[trialing active past_due]) }

      def activeish?
        status.in?(%w[trialing active past_due])
      end

      def last_synced_recently?(threshold: 15.minutes.ago)
        last_synced_at.present? && last_synced_at >= threshold
      end
    end
  end
end
