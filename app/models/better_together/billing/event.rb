# frozen_string_literal: true

module BetterTogether
  module Billing
    # Raw billing event log retained for auditability and replay.
    class Event < ApplicationRecord
      self.table_name = 'better_together_billing_events'

      PROCESSORS = %w[stripe].freeze
      SUPPORTED_OWNER_TYPES = %w[BetterTogether::Community BetterTogether::Person].freeze
      PROCESSING_STATUSES = %w[pending processed failed ignored].freeze

      belongs_to :billable_owner,
                 polymorphic: true,
                 optional: true
      belongs_to :beneficiary,
                 polymorphic: true,
                 optional: true
      belongs_to :billing_subscription,
                 class_name: 'BetterTogether::Billing::Subscription',
                 optional: true,
                 inverse_of: :billing_events

      validates :processor, inclusion: { in: PROCESSORS }
      validates :event_type, :event_id, presence: true
      validates :event_id, uniqueness: { scope: :processor }
      validates :processing_status, inclusion: { in: PROCESSING_STATUSES }
      validate :billable_owner_type_supported
      validate :beneficiary_type_supported

      scope :pending, -> { where(processing_status: 'pending') }

      def processed?
        processing_status == 'processed'
      end

      def failed?
        processing_status == 'failed'
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
