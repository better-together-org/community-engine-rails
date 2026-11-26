# frozen_string_literal: true

module BetterTogether
  module Billing
    # One line of the credit history: money into or out of one lot, with the balance after it. Entries
    # are never changed or removed once written; a mistake is corrected by a later entry.
    class CreditEntry < ApplicationRecord
      include PlatformBound
      include ParentBound

      self.table_name = 'better_together_billing_credit_entries'

      KINDS = %w[grant spend spend_reversal expire adjust forfeit].freeze
      # What an entry can be about, by class name: nothing is ever resolved from a string the caller sent.
      SOURCE_TYPES = %w[BetterTogether::Billing::Payment BetterTogether::Billing::Refund].freeze

      belongs_to :account, class_name: 'BetterTogether::Billing::CreditAccount', foreign_key: :credit_account_id,
                           inverse_of: :entries, optional: false
      belongs_to :lot, class_name: 'BetterTogether::Billing::CreditLot', foreign_key: :credit_lot_id,
                       inverse_of: :entries, optional: false
      belongs_to :reverses_entry, class_name: 'BetterTogether::Billing::CreditEntry', optional: true
      belongs_to :actor, class_name: 'BetterTogether::Person', optional: true
      belongs_to :source, polymorphic: true, optional: true

      validates :kind, inclusion: { in: KINDS }
      validates :transaction_key, presence: true, uniqueness: { scope: %i[platform_id credit_lot_id] }
      validates :amount_cents, numericality: { only_integer: true, other_than: 0 }
      validates :balance_after_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :source_type, inclusion: { in: SOURCE_TYPES }, allow_nil: true
      validates :note, length: { maximum: 255 }
      validate :sign_matches_kind
      validate :lot_belongs_to_account

      scope :spends, -> { where(kind: 'spend') }
      scope :newest_first, -> { order(created_at: :desc, id: :desc) }

      # The history is append-only.
      def readonly? = !new_record?

      def destroy = raise(ActiveRecord::ReadOnlyRecord, 'credit entries are never removed')

      private

      def billing_parent = account

      def sign_matches_kind
        return if amount_cents.to_i.zero?

        positive = %w[grant spend_reversal].include?(kind)
        negative = %w[spend expire forfeit].include?(kind)
        errors.add(:amount_cents, :wrong_sign) if (positive && amount_cents.negative?) || (negative && amount_cents.positive?)
      end

      def lot_belongs_to_account
        errors.add(:lot, :account_mismatch) if lot && account && lot.credit_account_id != account.id
      end
    end
  end
end
