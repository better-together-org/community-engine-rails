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

      # `processing`: the processor has the money in flight (a bank debit); it is neither paid nor
      # failed yet, so the order is not let go while it is.
      STATUSES = %w[pending processing succeeded failed cancelled partially_refunded refunded].freeze
      # A failed or cancelled payment can still succeed when the processor reports money for it (a
      # declined card retried in the same session, a session that outlived the order's hold): the
      # processor, not our hold, is the authority on whether money arrived. Refunds can fail, which
      # moves a refunded payment back (see Payment#refresh_refund_status!).
      TRANSITIONS = {
        'pending' => %w[processing succeeded failed cancelled],
        'processing' => %w[succeeded failed cancelled],
        'succeeded' => %w[partially_refunded refunded],
        'partially_refunded' => %w[succeeded partially_refunded refunded],
        'failed' => %w[pending succeeded],
        'cancelled' => %w[succeeded],
        'refunded' => %w[succeeded partially_refunded]
      }.freeze
      # Not yet paid or failed: counted against what an order still owes.
      IN_FLIGHT = %w[pending processing].freeze

      belongs_to :order, class_name: 'BetterTogether::Billing::Order', inverse_of: :payments, optional: false
      # The charge Pay recorded for this payment (a processor payment, once there is one).
      belongs_to :pay_charge, class_name: 'Pay::Charge', optional: true
      has_one :offline_payment, class_name: 'BetterTogether::Billing::OfflinePayment', inverse_of: :payment, dependent: :restrict_with_error
      has_many :refunds, class_name: 'BetterTogether::Billing::Refund', inverse_of: :payment, dependent: :restrict_with_error

      validates :processor, presence: true
      validates :status, inclusion: { in: STATUSES }
      validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
      validates :currency, inclusion: { in: Plan::SUPPORTED_CURRENCY_CODES }
      validates :idempotency_key, presence: true, uniqueness: { scope: :platform_id }
      validate :method_installed
      validate :pay_charge_on_this_platform
      validate :status_transition_allowed, on: :update

      STATUSES.each do |status|
        scope status.to_sym, -> { where(status:) }
        define_method(:"#{status}?") { self.status == status }
      end

      scope :in_flight, -> { where(status: IN_FLIGHT) }

      def in_flight? = IN_FLIGHT.include?(status)

      # Money arrived for an order that was cancelled: nobody is owed it, so it has to go back.
      def orphaned? = succeeded? && order.cancelled?

      # A payment that goes through a processor, not one core settles itself.
      def remote? = !Billing.local_method?(processor)

      def refunded_cents = refunds.where(status: Refund::COUNTED).sum(:amount_cents)

      # The payment's own status follows its refunds: none counted is `succeeded` again (a refund can
      # fail after it was recorded), all of it is `refunded`, anything between is `partially_refunded`.
      def refresh_refund_status!
        counted = refunded_cents
        target = if counted.zero? then 'succeeded'
                 elsif counted >= amount_cents then 'refunded'
                 else 'partially_refunded'
                 end
        update!(status: target) unless status == target
      end

      def refundable_cents = succeeded_or_refunding? ? amount_cents - refunded_cents : 0

      private

      def billing_parent = order

      def succeeded_or_refunding? = %w[succeeded partially_refunded].include?(status)

      def pay_charge_on_this_platform
        return if pay_charge.blank? || pay_charge.platform_id == platform_id

        errors.add(:pay_charge, :platform_owner_mismatch)
      end

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
