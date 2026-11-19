# frozen_string_literal: true

module BetterTogether
  module Billing
    # What a person holds in store credit with one platform, in one currency. Credit is the
    # platform's own money: it is spent only on what the platform itself sells.
    #
    # The balance is a cache of the lots (see Credit::Recalculate); everything that changes it goes
    # through Billing::Credit, under this record's lock, and leaves an entry behind.
    class CreditAccount < ApplicationRecord
      include PlatformBound

      self.table_name = 'better_together_billing_credit_accounts'

      belongs_to :holder, class_name: 'BetterTogether::Person', optional: true
      has_many :lots, class_name: 'BetterTogether::Billing::CreditLot', inverse_of: :account, dependent: :restrict_with_error
      has_many :entries, class_name: 'BetterTogether::Billing::CreditEntry', inverse_of: :account, dependent: :restrict_with_error

      attr_readonly :holder_id, :currency

      validates :currency, inclusion: { in: Plan::SUPPORTED_CURRENCY_CODES }
      validates :balance_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :holder_id, uniqueness: { scope: %i[platform_id currency] }, allow_nil: true

      # What can be spent now on a purchase of this kind: unexpired lots that allow the purpose.
      def usable_cents(purpose: nil, now: Time.current)
        lots.usable(purpose:, now:).sum(:remaining_cents)
      end

      # Whether the cached balance agrees with the lots and with the entries.
      def consistent?
        balance_cents == lots.sum(:remaining_cents) && balance_cents == entries.sum(:amount_cents)
      end
    end
  end
end
