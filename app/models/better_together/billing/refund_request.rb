# frozen_string_literal: true

module BetterTogether
  module Billing
    # A buyer asks for money back on an order they paid; the seller approves (all or part) or declines, once.
    #
    # Only money Community Engine settles itself can be asked for here (cash, cheque, e-transfer, store credit):
    # a vendor refund is made at the vendor and reported by it. Approving records ordinary refunds against the
    # order's payments (see RefundRequests::Decide), so tax, credit and order status behave as for any refund.
    # What the buyer wrote and what the seller answered are free text from people, so they are encrypted at rest.
    class RefundRequest < ApplicationRecord
      include PlatformBound
      include ParentBound
      include Subjectable
      include EncryptedAttributes

      self.table_name = 'better_together_billing_refund_requests'

      STATUSES = %w[pending approved partially_approved declined cancelled].freeze
      DECIDED = %w[approved partially_approved declined].freeze
      BUYER_REASONS = %w[requested_by_buyer duplicate cancelled_event error other].freeze
      DETAILS_LIMIT = 2_000

      encrypts_billing_attribute :details
      encrypts_billing_attribute :decision_note

      belongs_to :order, class_name: 'BetterTogether::Billing::Order', inverse_of: :refund_requests
      belongs_to :requester, class_name: 'BetterTogether::Person'
      belongs_to :decided_by, class_name: 'BetterTogether::Person', optional: true

      validates :status, inclusion: { in: STATUSES }
      validates :reason, inclusion: { in: BUYER_REASONS }
      validates :currency, inclusion: { in: Plan::SUPPORTED_CURRENCY_CODES }
      validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
      validates :approved_amount_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
      validate :details_short
      validate :requested_by_the_buyer, on: :create
      validate :something_to_give_back, on: :create
      validate :within_what_can_be_given_back, on: :create
      validate :no_other_pending_request, on: :create

      scope :pending, -> { where(status: 'pending') }
      scope :newest_first, -> { order(created_at: :desc) }

      # The money on an order that can be given back here: payments Community Engine settles itself.
      def self.refundable_cents_for(order)
        order.payments.select { |payment| Billing.local_method?(payment.processor) }.sum(&:refundable_cents)
      end

      def pending? = status == 'pending'

      def decided? = DECIDED.include?(status)

      private

      def billing_parent = order

      def details_short
        errors.add(:details, :too_long, count: DETAILS_LIMIT) if details.to_s.length > DETAILS_LIMIT
      end

      def requested_by_the_buyer
        errors.add(:requester, :not_the_buyer) unless order && requester && order.buyer_id == requester.id
      end

      def something_to_give_back
        errors.add(:base, :nothing_to_give_back) if order && self.class.refundable_cents_for(order) <= 0
      end

      def within_what_can_be_given_back
        return unless order && amount_cents

        return unless amount_cents > self.class.refundable_cents_for(order)

        errors.add(:amount_cents, :greater_than_refundable,
                   count: self.class.refundable_cents_for(order))
      end

      def no_other_pending_request
        errors.add(:base, :already_pending) if order && order.refund_requests.pending.where.not(id:).exists?
      end
    end
  end
end
