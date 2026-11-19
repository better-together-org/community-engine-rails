# frozen_string_literal: true

module BetterTogether
  module Billing
    # One billing period of a subscription Community Engine renews itself, and the order that invoices it.
    # Pay keeps only the current period, so the history lives here. Unique per subscription and sequence,
    # which is what makes making a renewal twice harmless.
    #
    # * pending: the period is coming (or running) and its invoice is waiting or not yet made
    # * needs_agreement: the payer has to accept a changed agreement before the invoice can be made
    # * blocked: the invoice could not be made for another reason (the method was switched off, say)
    # * paid, waived: covered. * lapsed: the grace ran out unpaid
    class SubscriptionPeriod < ApplicationRecord
      include PlatformBound
      include ParentBound
      include Subjectable

      self.table_name = 'better_together_billing_subscription_periods'

      STATUSES = %w[pending needs_agreement blocked paid waived lapsed].freeze
      OPEN = %w[pending needs_agreement blocked].freeze

      belongs_to :term, class_name: 'BetterTogether::Billing::SubscriptionTerm', foreign_key: :subscription_term_id, inverse_of: :periods,
                        optional: false
      belongs_to :order, class_name: 'BetterTogether::Billing::Order', optional: true

      attr_readonly :subscription_term_id, :sequence, :starts_at, :ends_at

      validates :sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, uniqueness: { scope: :subscription_term_id }
      validates :status, inclusion: { in: STATUSES }
      validates :starts_at, :ends_at, presence: true
      validate :ends_after_start
      validate :order_on_this_platform

      STATUSES.each do |status|
        scope status.to_sym, -> { where(status:) }
        define_method(:"#{status}?") { self.status == status }
      end
      scope :unsettled, -> { where(status: OPEN) }

      def unsettled? = OPEN.include?(status)

      def covered? = paid? || waived?

      private

      def billing_parent = term

      def ends_after_start
        errors.add(:ends_at, :after_start) if starts_at && ends_at && ends_at <= starts_at
      end

      def order_on_this_platform
        errors.add(:order, :platform_owner_mismatch) if order && order.platform_id != platform_id
      end
    end
  end
end
