# frozen_string_literal: true

module BetterTogether
  module Billing
    # One payment made against an order, through one method: a vendor processor, cash, store
    # credit. An order paid in parts has several. The idempotency key makes a repeated request
    # (a double click, a retried job) find the payment it already made instead of making another.
    class Payment < ApplicationRecord
      include PlatformBound
      include ParentBound

      self.table_name = 'better_together_billing_payments'

      STATUSES = %w[pending succeeded failed cancelled partially_refunded refunded].freeze
      TRANSITIONS = {
        'pending' => %w[succeeded failed cancelled],
        'succeeded' => %w[partially_refunded refunded],
        'partially_refunded' => %w[partially_refunded refunded],
        'failed' => %w[pending],
        'cancelled' => [],
        'refunded' => []
      }.freeze

      belongs_to :order, class_name: 'BetterTogether::Billing::Order', inverse_of: :payments, optional: false
      has_one :offline_payment, class_name: 'BetterTogether::Billing::OfflinePayment', inverse_of: :payment, dependent: :restrict_with_error
      has_many :refunds, class_name: 'BetterTogether::Billing::Refund', inverse_of: :payment, dependent: :restrict_with_error

      validates :processor, presence: true
      validates :status, inclusion: { in: STATUSES }
      validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
      validates :currency, inclusion: { in: Plan::SUPPORTED_CURRENCY_CODES }
      validates :idempotency_key, presence: true, uniqueness: { scope: :platform_id }
      validate :method_installed
      validate :status_transition_allowed, on: :update

      STATUSES.each do |status|
        scope status.to_sym, -> { where(status:) }
        define_method(:"#{status}?") { self.status == status }
      end

      def refunded_cents = refunds.where(status: Refund::COUNTED).sum(:amount_cents)

      def refundable_cents = succeeded_or_refunding? ? amount_cents - refunded_cents : 0

      private

      def billing_parent = order

      def succeeded_or_refunding? = %w[succeeded partially_refunded].include?(status)

      def method_installed
        return if processor.blank?

        errors.add(:processor, :not_installed) unless Billing.processor_names.map(&:to_s).include?(processor)
      end

      def status_transition_allowed
        return unless status_changed?

        was = status_was
        return if TRANSITIONS.fetch(was, []).include?(status)

        errors.add(:status, :transition_not_allowed, from: was, to: status)
      end
    end
  end
end
