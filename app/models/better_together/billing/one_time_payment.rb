# frozen_string_literal: true

module BetterTogether
  module Billing
    # Local record of a completed one-time (non-subscription) Stripe Checkout
    # payment. Unlike Billing::Subscription, this has no Pay::Subscription
    # dependency — one-time payments have no recurring processor state to
    # delegate to.
    class OneTimePayment < ApplicationRecord
      self.table_name = 'better_together_billing_one_time_payments'

      STATUSES = %w[succeeded refunded].freeze

      belongs_to :owner, polymorphic: true
      belongs_to :billing_plan,
                 class_name: 'BetterTogether::Billing::Plan',
                 inverse_of: :one_time_payments

      validates :stripe_checkout_session_id, presence: true, uniqueness: true
      validates :amount_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
      validates :currency, presence: true, length: { is: 3 }
      validates :status, inclusion: { in: STATUSES }

      def succeeded?
        status == 'succeeded'
      end

      def refunded?
        status == 'refunded'
      end
    end
  end
end
