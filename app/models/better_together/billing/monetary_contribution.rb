# frozen_string_literal: true

module BetterTogether
  module Billing
    # A single credit to a beneficiary's Stripe Customer Balance, funded by a
    # sponsor. Audit mirror of a real Stripe balance_transaction — not the
    # source of truth for the balance itself (Stripe is).
    class MonetaryContribution < ApplicationRecord
      self.table_name = 'better_together_billing_monetary_contributions'

      belongs_to :sponsorship,
                 class_name: 'BetterTogether::Billing::Sponsorship',
                 inverse_of: :monetary_contributions
      belongs_to :one_time_payment,
                 class_name: 'BetterTogether::Billing::OneTimePayment',
                 optional: true

      validates :amount_cents, numericality: { greater_than: 0, only_integer: true }
      validates :currency, presence: true, length: { is: 3 }
      validates :stripe_balance_transaction_id, presence: true, uniqueness: true

      delegate :sponsor, :beneficiary, to: :sponsorship
    end
  end
end
