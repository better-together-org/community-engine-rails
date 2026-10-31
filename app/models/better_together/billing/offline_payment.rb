# frozen_string_literal: true

module BetterTogether
  module Billing
    # An order being paid with money the platform cannot see: cash, a cheque, an e-transfer.
    #
    # It sits beside the order's core Payment and holds what only these methods have: the buyer's
    # optional "I sent it", the seller's word that the money arrived, and a snapshot of what the
    # buyer was told about how to pay.
    #
    # THE SELLER DECIDES. Only the seller's confirmation makes the payment paid, and it never needs
    # the buyer to have said anything first: a buyer who paid in person, or sent a transfer
    # without telling anyone, is still fully payable. The buyer's claim only flags the order for
    # the seller; it never changes what the seller may do and never changes the status of a
    # payment the seller already confirmed. See OfflinePayments::Transition for the rules.
    #
    # The instructions are copied here when the order is placed (encrypted), so a seller who later
    # edits their payment details cannot redirect a buyer who is already part-way through paying,
    # and the record shows what the buyer was told.
    class OfflinePayment < ApplicationRecord
      include PlatformBound
      include ParentBound
      include EncryptedAttributes
      include Subjectable

      self.table_name = 'better_together_billing_offline_payments'

      STATUSES = %w[awaiting claimed received confirmed cleared bounced rejected expired cancelled].freeze
      # Waiting for the seller to say the money arrived.
      OPEN = %w[awaiting claimed].freeze
      # Where each status may go. `claimed` can repeat (the buyer adds a reference). An expired payment
      # can still be confirmed by a seller who was paid late. A cheque goes received, then cleared or
      # bounced; cash and an e-transfer go straight to confirmed.
      TRANSITIONS = {
        'awaiting' => %w[claimed received confirmed rejected expired cancelled],
        'claimed' => %w[claimed received confirmed rejected expired cancelled],
        'expired' => %w[received confirmed],
        'received' => %w[cleared bounced],
        'confirmed' => [],
        'cleared' => [],
        'bounced' => [],
        'rejected' => [],
        'cancelled' => []
      }.freeze
      # Statuses in which the seller has said the money arrived.
      RECEIVED = %w[received confirmed cleared].freeze
      GRANT_ON = %w[confirmed received cleared].freeze
      # How long after it lapsed a payment still shows in the seller's queue.
      LATE_WINDOW = 30.days
      REFERENCE_LIMIT = 200
      REASON_LIMIT = 200

      encrypts_billing_attribute :buyer_reference
      encrypts_billing_attribute :seller_reference
      encrypts_billing_attribute :instructions_snapshot, json: true, default: -> { {} }

      belongs_to :order, class_name: 'BetterTogether::Billing::Order', inverse_of: :offline_payments, optional: false
      belongs_to :payment, class_name: 'BetterTogether::Billing::Payment', inverse_of: :offline_payment, optional: false
      belongs_to :confirmed_by, class_name: 'BetterTogether::Person', optional: true

      attr_readonly :processor, :grant_on, :order_id, :instructions_snapshot

      before_validation :normalize

      validates :status, inclusion: { in: STATUSES }
      validates :grant_on, inclusion: { in: GRANT_ON }
      validates :platform_fee_cents, numericality: { only_integer: true, equal_to: 0 }
      validates :buyer_reference, :seller_reference, length: { maximum: REFERENCE_LIMIT }
      validates :rejection_reason, length: { maximum: REASON_LIMIT }
      validate :method_is_offline
      validate :payment_is_this_orders
      validate :status_transition_allowed, on: :update

      STATUSES.each do |status|
        scope status.to_sym, -> { where(status:) }
        define_method(:"#{status}?") { self.status == status }
      end
      scope :waiting, -> { where(status: OPEN) }
      # What the seller still has to deal with: waiting for them, a cheque not yet cleared, or lapsed
      # recently enough that a late payment may still turn up.
      scope :needing_attention, lambda {
        where(status: OPEN + %w[received]).or(where(status: 'expired').where(arel_table[:expired_at].gteq(LATE_WINDOW.ago)))
      }
      scope :oldest_first, -> { order(:created_at) }
      # Waiting for the seller since before `after` ago, and not reminded within that time.
      scope :due_a_reminder, lambda { |after|
        stale = waiting.where(arel_table[:created_at].lt(after.ago))
        stale.where(last_reminded_at: nil).or(stale.where(arel_table[:last_reminded_at].lt(after.ago)))
      }
      scope :newest_first, -> { order(created_at: :desc) }
      scope :lapsed, -> { waiting.where(arel_table[:expires_at].lt(Time.current)) }

      def waiting? = OPEN.include?(status)

      def money_received? = RECEIVED.include?(status)

      def can_become?(new_status) = TRANSITIONS.fetch(status, []).include?(new_status.to_s)

      def cheque? = processor == 'cheque'

      # The buyer says they sent it. Optional and informational.
      def claimed_by_buyer? = claimed_at.present?

      # The status the seller moves a payment to when they say the money arrived.
      def receipt_status = cheque? ? 'received' : 'confirmed'

      # Whether the seller's word that it arrived already counts as the order being paid.
      def grants_on_receipt? = grant_on != 'cleared' || !cheque?

      def instructions = instructions_snapshot.to_h

      private

      def billing_parent = order

      def normalize
        self.buyer_reference = buyer_reference.to_s.strip.presence
        self.seller_reference = seller_reference.to_s.strip.presence
        self.rejection_reason = rejection_reason.to_s.strip.presence
      end

      def method_is_offline
        errors.add(:processor, :not_an_offline_method, method: processor) unless Billing.offline_method?(processor)
      end

      def payment_is_this_orders
        errors.add(:payment, :invalid) if payment && order && payment.order_id != order.id
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
