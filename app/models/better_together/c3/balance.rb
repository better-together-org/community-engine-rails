# frozen_string_literal: true

module BetterTogether
  module C3
    # Balance tracks the running C3 token totals for a holder (Person or AgentActor).
    # available_millitokens — spendable C3 (not locked)
    # locked_millitokens — reserved for in-flight Joatu exchanges
    # lifetime_earned_millitokens — cumulative C3 ever earned (never decremented)
    class Balance < ApplicationRecord
      self.table_name = 'better_together_c3_balances'

      MILLITOKEN_SCALE = BetterTogether::C3::Token::MILLITOKEN_SCALE

      belongs_to :holder, polymorphic: true
      belongs_to :community, class_name: 'BetterTogether::Community', optional: true
      belongs_to :origin_platform, class_name: 'BetterTogether::Platform', optional: true

      # local: earned on this platform; federated: received via C3 cross-platform exchange
      scope :local,     -> { where(origin_platform_id: nil) }
      scope :federated, -> { where.not(origin_platform_id: nil) }

      validates :holder, presence: true
      validates :available_millitokens, :locked_millitokens, :lifetime_earned_millitokens,
                numericality: { greater_than_or_equal_to: 0 }

      # Credit C3 tokens to this balance (after a job completes)
      def credit!(c3_amount)
        millitokens = (c3_amount.to_f * MILLITOKEN_SCALE).round
        increment!(:available_millitokens, millitokens)
        increment!(:lifetime_earned_millitokens, millitokens)
      end

      # Lock C3 for a pending Joatu exchange
      def lock!(c3_amount)
        millitokens = (c3_amount.to_f * MILLITOKEN_SCALE).round
        raise InsufficientBalance, "Only #{available_c3} C3 available" if millitokens > available_millitokens

        decrement!(:available_millitokens, millitokens)
        increment!(:locked_millitokens, millitokens)
      end

      # Release locked C3 back to available (exchange cancelled)
      def unlock!(c3_amount)
        millitokens = (c3_amount.to_f * MILLITOKEN_SCALE).round
        decrement!(:locked_millitokens, millitokens)
        increment!(:available_millitokens, millitokens)
      end

      # Settle locked C3 to another balance (exchange fulfilled)
      def settle_to!(recipient_balance, c3_amount)
        millitokens = (c3_amount.to_f * MILLITOKEN_SCALE).round
        decrement!(:locked_millitokens, millitokens)
        recipient_balance.credit!(c3_amount)
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
    end
  end
end
