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

      # Lock C3 for a pending exchange.
      # Creates a BalanceLock audit record and returns its lock_ref.
      #
      # Optional kwargs:
      #   agreement_ref: (string) — caller-supplied agreement identifier
      #   source_platform: (Platform) — which platform requested this lock (nil = local)
      #   expires_in: (ActiveSupport::Duration) — override default 24h TTL
      #
      # @param c3_amount [String, Numeric] Tree Seed amount to lock
      # @raise [InsufficientBalance] if locked amount exceeds available balance
      def lock!(c3_amount, agreement_ref: nil, source_platform: nil, expires_in: nil) # rubocop:todo Metrics/MethodLength
        millitokens = BetterTogether::C3::Token.c3_to_millitokens(c3_amount)
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
        raise InsufficientBalance, "Only #{available_millitokens} millitokens available" if millitokens > available_millitokens

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

      # Release locked C3 back to available using exact integer millitokens.
      # Avoids float-rounding risk — prefer this method when the raw millitoken
      # count is already available (e.g. expiring a BalanceLock record).
      def unlock_millitokens!(amount_millitokens)
        transaction do
          raise LockError, "Only #{locked_millitokens} millitokens locked" if amount_millitokens > locked_millitokens

          decrement!(:locked_millitokens, amount_millitokens)
          increment!(:available_millitokens, amount_millitokens)
        end
      end

      # Release locked C3 back to available (exchange cancelled or lock expired).
      # If lock_ref is provided, marks the corresponding BalanceLock as released.
      #
      # @param c3_amount [String, Numeric] Tree Seed amount to unlock
      # @param lock_ref [String] Optional lock reference to mark as released
      # @raise [LockError] if lock_ref doesn't exist or amount doesn't match
      def unlock!(c3_amount, lock_ref: nil)
        millitokens = BetterTogether::C3::Token.c3_to_millitokens(c3_amount)
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

      # Release exact millitokens back to available, bypassing float conversion.
      # Prefer this method when working with existing millitokens values.
      #
      # @param amount_millitokens [Integer] Exact millitokens to unlock
      # @param lock_ref [String] Optional lock reference to mark as released
      # @raise [LockError] if lock_ref doesn't exist or amount exceeds locked balance
      def unlock_millitokens!(amount_millitokens, lock_ref: nil)
        millitokens = amount_millitokens.to_i
        transaction do
          lock = pending_lock_for_millitokens!(lock_ref, millitokens) if lock_ref.present?
          if lock_ref.blank? && millitokens > locked_millitokens
            raise LockError, "Only #{locked_millitokens} millitokens locked"
          end

          decrement!(:locked_millitokens, millitokens)
          increment!(:available_millitokens, millitokens)
          lock&.release!
        end
      end

      # Settle locked C3 to another balance (exchange fulfilled).
      # Marks the corresponding BalanceLock as settled if lock_ref is provided.
      #
      # @param recipient_balance [Balance] Recipient's balance to credit
      # @param c3_amount [String, Numeric] Tree Seed amount to settle
      # @param lock_ref [String] Optional lock reference to mark as settled
      # @raise [LockError] if lock_ref doesn't exist or amount doesn't match
      def settle_to!(recipient_balance, c3_amount, lock_ref: nil)
        millitokens = BetterTogether::C3::Token.c3_to_millitokens(c3_amount)
        transaction do
          lock = pending_lock_for!(lock_ref, millitokens) if lock_ref.present?
          if lock_ref.blank? && millitokens > locked_millitokens
            raise LockError, "Only #{locked_c3} C3 locked"
          end

          decrement!(:locked_millitokens, millitokens)
          recipient_balance.credit_millitokens!(millitokens)
          lock&.settle!
        end
      end

      # Settle exact millitokens to another balance, bypassing float conversion.
      # Prefer this method when millitokens value is already available (from BalanceLock).
      # Marks the corresponding BalanceLock as settled if lock_ref is provided.
      #
      # @param recipient_balance [Balance] Recipient's balance to credit
      # @param amount_millitokens [Integer] Exact millitokens to settle
      # @param lock_ref [String] Optional lock reference to mark as settled
      # @raise [LockError] if lock_ref doesn't exist or amount exceeds locked balance
      def settle_to_millitokens!(recipient_balance, amount_millitokens, lock_ref: nil)
        millitokens = amount_millitokens.to_i
        transaction do
          lock = pending_lock_for_millitokens!(lock_ref, millitokens) if lock_ref.present?
          if lock_ref.blank? && millitokens > locked_millitokens
            raise LockError, "Only #{locked_millitokens} millitokens locked"
          end

          decrement!(:locked_millitokens, millitokens)
          recipient_balance.credit_millitokens!(millitokens)
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

      def pending_lock_for_millitokens!(lock_ref, expected_millitokens)
        lock = balance_locks.pending.find_by(lock_ref: lock_ref)
        raise LockError, "pending lock '#{lock_ref}' not found" if lock.nil?
        raise LockError, "pending lock '#{lock_ref}' amount does not match settlement" if lock.millitokens != expected_millitokens.to_i

        lock
      end
    end
  end
end
