# frozen_string_literal: true

module BetterTogether
  module Billing
    # One amount of credit that came in, with its own expiry and the purchases it may pay for. Spending
    # takes from the lot that expires soonest, so promotional credit is used before it lapses.
    class CreditLot < ApplicationRecord
      include PlatformBound
      include ParentBound

      self.table_name = 'better_together_billing_credit_lots'

      ORIGINS = %w[steward_grant promotion refund adjustment].freeze

      belongs_to :account, class_name: 'BetterTogether::Billing::CreditAccount', foreign_key: :credit_account_id,
                           inverse_of: :lots, optional: false
      belongs_to :granted_by, class_name: 'BetterTogether::Person', optional: true
      has_many :entries, class_name: 'BetterTogether::Billing::CreditEntry', foreign_key: :credit_lot_id, inverse_of: :lot,
                         dependent: :restrict_with_error

      attr_readonly :amount_cents, :origin, :credit_account_id

      validates :origin, inclusion: { in: ORIGINS }
      validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
      validates :remaining_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: :amount_cents },
                                  if: -> { amount_cents.to_i.positive? }
      validates :note, length: { maximum: 255 }
      validate :purposes_known

      # Unexpired lots with something left that may pay for `purpose` (any purpose when none is named).
      scope :usable, lambda { |purpose: nil, now: Time.current|
        base = where(arel_table[:remaining_cents].gt(0)).where(arel_table[:expires_at].eq(nil).or(arel_table[:expires_at].gt(now)))
        purpose.present? ? base.where(allows_purpose_condition(purpose.to_s)) : base
      }
      # Expiring soonest first, never expiring last: the order credit is spent in.
      scope :soonest_expiring, -> { order(arel_table[:expires_at].asc.nulls_last, :created_at, :id) }
      # Lots with something left whose date has passed.
      scope :lapsed, ->(now = Time.current) { where(arel_table[:remaining_cents].gt(0)).where(arel_table[:expires_at].lteq(now)) }

      # No purposes named means any; otherwise the purpose must be one of them.
      def self.allows_purpose_condition(purpose)
        any = Arel::Nodes::InfixOperation.new('=', Arel::Nodes.build_quoted(purpose),
                                              Arel::Nodes::NamedFunction.new('ANY', [arel_table[:purposes]]))
        Arel::Nodes::NamedFunction.new('cardinality', [arel_table[:purposes]]).eq(0).or(any)
      end

      def expired?(now = Time.current) = expires_at.present? && expires_at <= now

      private

      def billing_parent = account

      def purposes_known
        self.purposes = Array(purposes).map(&:to_s).compact_blank.uniq
        errors.add(:purposes, :inclusion) if (purposes - ProcessorSetting::PURPOSES).any?
      end
    end
  end
end
