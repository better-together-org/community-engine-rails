# frozen_string_literal: true

module BetterTogether
  module C3
    # Mixin for Balance locking and settlement operations.
    # Manages reserving C3 tokens for pending exchanges and releasing them.
    module BalanceLocking
      extend ActiveSupport::Concern

      included do
        validates :locked_millitokens, numericality: { greater_than_or_equal_to: 0 }
      end

      MILLITOKEN_SCALE = BetterTogether::C3::Token::MILLITOKEN_SCALE

      # Lock C3 tokens for a pending exchange. Creates a BalanceLock audit record.
      #
      # Named lock_c3! (not lock!) to avoid shadowing ActiveRecord::Locking::Pessimistic#lock!,
      # which is called internally by with_lock. Shadowing it breaks pessimistic row locking.
      #
      # @param c3_amount [String, Numeric] Tree Seed amount to lock
      # @param agreement_ref [String] Optional caller-supplied agreement identifier
      # @param source_platform [Platform] Optional platform that requested this lock
      # @param expires_in [ActiveSupport::Duration] Optional override for 24h TTL
      # @raise [InsufficientBalance] if locked amount exceeds available balance
      def lock_c3!(c3_amount, agreement_ref: nil, source_platform: nil, expires_in: nil) # rubocop:todo Metrics/MethodLength
        millitokens = BetterTogether::C3::Token.c3_to_millitokens(c3_amount)
        lock_millitokens!(millitokens, agreement_ref: agreement_ref,
                                       source_platform: source_platform, expires_in: expires_in)
      end

      # Lock exact millitokens for a pending exchange, bypassing float conversion.
      # Prefer this method when millitokens value is already available.
      # Creates a BalanceLock audit record and returns its lock_ref.
      #
      # @param amount_millitokens [Integer] Exact millitokens to lock
      # @param agreement_ref [String] Optional caller-supplied agreement identifier
      # @param source_platform [Platform] Optional platform that requested this lock
      # @param expires_in [ActiveSupport::Duration] Optional override for 24h TTL
      # @raise [InsufficientBalance] if locked amount exceeds available balance
      def lock_millitokens!(amount_millitokens, agreement_ref: nil, source_platform: nil, expires_in: nil) # rubocop:todo Metrics/MethodLength
        millitokens = amount_millitokens.to_i
        lock_record = nil

        with_lock do
          if millitokens > available_millitokens
            raise BetterTogether::C3::Balance::InsufficientBalance,
                  "Only #{available_millitokens} millitokens available"
          end

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

      # Release locked C3 back to available, bypassing float conversion.
      # Prefer this method when working with existing millitokens values.
      #
      # @param amount_millitokens [Integer] Exact millitokens to unlock
      # @raise [LockError] if amount exceeds locked balance
      def unlock_millitokens!(amount_millitokens)
        transaction do
          if amount_millitokens > locked_millitokens
            raise BetterTogether::C3::Balance::LockError,
                  "Only #{locked_millitokens} millitokens locked"
          end

          decrement!(:locked_millitokens, amount_millitokens)
          increment!(:available_millitokens, amount_millitokens)
        end
      end

      # Release locked C3 back to available (exchange cancelled or lock expired).
      # If lock_ref is provided, validates the pending lock exists before modifying balances,
      # then marks the BalanceLock as released.
      #
      # @param c3_amount [String, Numeric] Tree Seed amount to unlock
      # @param lock_ref [String] Optional lock reference to mark as released
      # @raise [LockError] if lock_ref doesn't exist, is already consumed, or amount doesn't match
      def unlock!(c3_amount, lock_ref: nil)
        millitokens = BetterTogether::C3::Token.c3_to_millitokens(c3_amount)
        lock = validate_pending_lock!(lock_ref, millitokens)
        unlock_millitokens!(millitokens)
        lock&.release!
      end

      # Settle locked C3 to another balance (exchange fulfilled).
      # Marks the corresponding BalanceLock as settled if lock_ref is provided.
      #
      # @param recipient_balance [Balance] Balance to receive the C3
      # @param c3_amount [String, Numeric] Tree Seed amount to transfer
      # @param lock_ref [String] Optional lock reference to mark as settled
      def settle_to!(recipient_balance, c3_amount, lock_ref: nil)
        millitokens = BetterTogether::C3::Token.c3_to_millitokens(c3_amount)
        settle_to_millitokens!(recipient_balance, millitokens, lock_ref: lock_ref)
      end

      # Settle exact millitokens to another balance, bypassing float conversion.
      # Validates the pending lock exists before modifying balances, then marks it settled.
      #
      # @param recipient_balance [Balance] Balance to receive the C3
      # @param amount_millitokens [Integer] Exact millitokens to transfer
      # @param lock_ref [String] Optional lock reference to mark as settled
      # @raise [LockError] if lock_ref doesn't exist or is already consumed
      # @raise [LockMismatch] if lock exists but amount doesn't match
      def settle_to_millitokens!(recipient_balance, amount_millitokens, lock_ref: nil)
        lock = validate_pending_lock!(lock_ref, amount_millitokens)
        transaction do
          debit_locked!(amount_millitokens)
          recipient_balance.credit_millitokens!(amount_millitokens)
          lock&.settle!
        end
      end

      private

      def validate_pending_lock!(lock_ref, expected_millitokens)
        return nil unless lock_ref.present?

        lock = balance_locks.find_by(lock_ref: lock_ref, status: :pending)
        raise BetterTogether::C3::Balance::LockError, "pending lock '#{lock_ref}' not found" unless lock
        raise BetterTogether::C3::Balance::LockMismatch, 'Lock millitokens mismatch' if lock.millitokens != expected_millitokens

        lock
      end

      def debit_locked!(amount_millitokens)
        raise BetterTogether::C3::Balance::LockError, "Only #{locked_millitokens} millitokens locked" if amount_millitokens > locked_millitokens

        decrement!(:locked_millitokens, amount_millitokens)
      end
    end
  end
end
