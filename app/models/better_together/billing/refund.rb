# frozen_string_literal: true

module BetterTogether
  module Billing
    # Money given back against one payment. For a vendor processor it is made at the processor;
    # for cash, a cheque or an e-transfer the seller records that they handed it back
    # (status `recorded`), since the platform cannot see it.
    class Refund < ApplicationRecord
      include PlatformBound
      include ParentBound

      self.table_name = 'better_together_billing_refunds'

      STATUSES = %w[pending succeeded failed recorded].freeze
      # The statuses that count as money already given back.
      COUNTED = %w[pending succeeded recorded].freeze
      REASONS = %w[requested_by_buyer duplicate cancelled_event cancelled_order bounced error other].freeze

      belongs_to :payment, class_name: 'BetterTogether::Billing::Payment', inverse_of: :refunds, optional: false
      belongs_to :recorded_by, class_name: 'BetterTogether::Person', optional: true

      validates :status, inclusion: { in: STATUSES }
      validates :reason, inclusion: { in: REASONS }, allow_blank: true
      validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
      validates :currency, inclusion: { in: Plan::SUPPORTED_CURRENCY_CODES }
      validates :idempotency_key, presence: true, uniqueness: { scope: :platform_id }
      validate :within_what_is_left, on: :create

      def counted? = COUNTED.include?(status)

      private

      def billing_parent = payment

      def within_what_is_left
        return unless payment

        errors.add(:amount_cents, :greater_than_refundable, count: payment.refundable_cents) if amount_cents.to_i > payment.refundable_cents
      end
    end
  end
end
