# frozen_string_literal: true

module BetterTogether
  module Billing
    # Raw billing event log retained for auditability and replay.
    class Event < ApplicationRecord
      self.table_name = 'better_together_billing_events'

      PROCESSORS = %w[stripe].freeze
      PROCESSING_STATUSES = %w[pending processed failed ignored].freeze

      belongs_to :community,
                 class_name: 'BetterTogether::Community',
                 optional: true,
                 inverse_of: :billing_events
      belongs_to :billing_subscription,
                 class_name: 'BetterTogether::Billing::Subscription',
                 optional: true,
                 inverse_of: :billing_events

      validates :processor, inclusion: { in: PROCESSORS }
      validates :event_type, :event_id, presence: true
      validates :event_id, uniqueness: { scope: :processor }
      validates :processing_status, inclusion: { in: PROCESSING_STATUSES }

      scope :pending, -> { where(processing_status: 'pending') }

      def processed?
        processing_status == 'processed'
      end

      def failed?
        processing_status == 'failed'
      end
    end
  end
end
