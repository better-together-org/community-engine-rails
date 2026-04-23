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

      has_many :balance_locks, class_name: 'BetterTogether::C3::BalanceLock',
                               foreign_key: :balance_id, dependent: :destroy

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

      # Lock C3 for a pending exchange.
      # Creates a BalanceLock audit record and returns its lock_ref.
      #
      # Optional kwargs:
      #   agreement_ref: (string) — caller-supplied agreement identifier
      #   source_platform: (Platform) — which platform requested this lock (nil = local)
      #   expires_in: (ActiveSupport::Duration) — override default 24h TTL
      def lock!(c3_amount, agreement_ref: nil, source_platform: nil, expires_in: nil) # rubocop:todo Metrics/MethodLength
        millitokens = (c3_amount.to_f * MILLITOKEN_SCALE).round
        raise InsufficientBalance, "Only #{available_c3} C3 available" if millitokens > available_millitokens

        lock_record = nil
        transaction do
          decrement!(:available_millitokens, millitokens)
          increment!(:locked_millitokens, millitokens)
          lock_record = balance_locks.create!(
            millitokens: millitokens,
            agreement_ref: agreement_ref,
            source_platform: source_platform,
            expires_at: expires_in&.from_now
          )
        end
        lock_record.lock_ref
      end

      # Release locked C3 back to available (exchange cancelled or lock expired).
      # If lock_ref is provided, marks the corresponding BalanceLock as released.
      def unlock!(c3_amount, lock_ref: nil)
        millitokens = (c3_amount.to_f * MILLITOKEN_SCALE).round
        transaction do
          lock = pending_lock_for!(lock_ref, millitokens) if lock_ref.present?
          if lock_ref.blank? && millitokens > locked_millitokens
            raise LockError, "Only #{locked_c3} C3 locked"
          end

          decrement!(:locked_millitokens, millitokens)
          increment!(:available_millitokens, millitokens)
          lock&.release!
        end
      end

      # Settle locked C3 to another balance (exchange fulfilled).
      # Marks the corresponding BalanceLock as settled if lock_ref is provided.
      def settle_to!(recipient_balance, c3_amount, lock_ref: nil)
        millitokens = (c3_amount.to_f * MILLITOKEN_SCALE).round
        transaction do
          lock = pending_lock_for!(lock_ref, millitokens) if lock_ref.present?
          if lock_ref.blank? && millitokens > locked_millitokens
            raise LockError, "Only #{locked_c3} C3 locked"
          end

          decrement!(:locked_millitokens, millitokens)
          recipient_balance.credit!(c3_amount)
          lock&.settle!
        end
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

      private

      def pending_lock_for!(lock_ref, expected_millitokens)
        lock = balance_locks.pending.find_by(lock_ref: lock_ref)
        raise LockError, "pending lock '#{lock_ref}' not found" if lock.nil?
        raise LockError, "pending lock '#{lock_ref}' amount does not match settlement" if lock.millitokens != expected_millitokens

        lock
      end
    end
  end
end
