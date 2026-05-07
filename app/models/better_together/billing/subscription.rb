# frozen_string_literal: true

module BetterTogether
  module Billing
    # Local subscription record synced from the payment processor.
    class Subscription < ApplicationRecord
      self.table_name = 'better_together_billing_subscriptions'

      PROCESSORS = %w[stripe].freeze
      SUPPORTED_OWNER_TYPES = %w[BetterTogether::Community BetterTogether::Person].freeze
      STATUSES = %w[
        incomplete
        trialing
        active
        past_due
        canceled
        unpaid
        paused
      ].freeze

      belongs_to :billable_owner,
                 polymorphic: true
      belongs_to :beneficiary,
                 polymorphic: true
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
      validates :billable_owner, :beneficiary, :billing_plan, presence: true
      validates :cancel_at_period_end, inclusion: { in: [true, false] }
      validate :billable_owner_type_supported
      validate :beneficiary_type_supported

      scope :activeish, -> { where(status: %w[trialing active past_due]) }

      def activeish?
        status.in?(%w[trialing active past_due])
      end

      def last_synced_recently?(threshold: 15.minutes.ago)
        last_synced_at.present? && last_synced_at >= threshold
      end

      def community
        owner_or_beneficiary_of_type(BetterTogether::Community)
      end

      def person
        owner_or_beneficiary_of_type(BetterTogether::Person)
      end

      private

      def owner_or_beneficiary_of_type(klass)
        return beneficiary if beneficiary.is_a?(klass)
        return billable_owner if billable_owner.is_a?(klass)

        nil
      end

      def billable_owner_type_supported
        return if billable_owner_type.blank? || billable_owner_type.in?(SUPPORTED_OWNER_TYPES)

        errors.add(:billable_owner_type, :inclusion)
      end

      def beneficiary_type_supported
        return if beneficiary_type.blank? || beneficiary_type.in?(SUPPORTED_OWNER_TYPES)

        errors.add(:beneficiary_type, :inclusion)
      end
    end
  end
end
