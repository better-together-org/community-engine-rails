# frozen_string_literal: true

module BetterTogether
  module C3
    # Balance tracks the running C3 token totals for a holder (Person or AgentActor).
    # available_millitokens — spendable C3 (not locked)
    # locked_millitokens — reserved for in-flight Joatu exchanges
    # lifetime_earned_millitokens — cumulative C3 ever earned (never decremented)
    class Balance < ApplicationRecord
      include BalanceLocking

      self.table_name = 'better_together_c3_balances'

      MILLITOKEN_SCALE = BetterTogether::C3::Token::MILLITOKEN_SCALE

      belongs_to :holder, polymorphic: true
      belongs_to :community, class_name: 'BetterTogether::Community', optional: true
      belongs_to :origin_platform, class_name: 'BetterTogether::Platform', optional: true

      has_many :balance_locks, class_name: 'BetterTogether::C3::BalanceLock',
                               foreign_key: :balance_id, dependent: :destroy

      # local: earned on this platform; federated: received via C3 cross-platform exchange
      scope :local,     -> { where(origin_platform_id: nil) }
      scope :federated, -> { where.not(origin_platform_id: nil) }

      validates :holder, presence: true
      validates :available_millitokens, :locked_millitokens, :lifetime_earned_millitokens,
                numericality: { greater_than_or_equal_to: 0 }

      # Credit C3 tokens to this balance (after a job completes)
      # @param c3_amount [String, Numeric] Tree Seed amount
      def credit!(c3_amount)
        millitokens = BetterTogether::C3::Token.c3_to_millitokens(c3_amount)
        increment!(:available_millitokens, millitokens)
        increment!(:lifetime_earned_millitokens, millitokens)
      end

      # Credit exact millitokens to this balance, bypassing float conversion.
      # Prefer this method when working with existing millitokens values (e.g., from BalanceLock).
      # @param amount_millitokens [Integer] Exact millitokens to credit
      def credit_millitokens!(amount_millitokens)
        amount_millitokens = amount_millitokens.to_i
        increment!(:available_millitokens, amount_millitokens)
        increment!(:lifetime_earned_millitokens, amount_millitokens)
      end

      def available_c3
        available_millitokens.to_f / MILLITOKEN_SCALE
      end

      def locked_c3
        locked_millitokens.to_f / MILLITOKEN_SCALE
      end

      def lifetime_earned_c3
        lifetime_earned_millitokens.to_f / MILLITOKEN_SCALE
      end

      class InsufficientBalance < StandardError; end
      class LockError < StandardError; end
      class LockMismatch < StandardError; end
    end
  end
end
