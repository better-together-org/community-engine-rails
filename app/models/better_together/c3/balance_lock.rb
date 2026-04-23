# frozen_string_literal: true

module BetterTogether
  module C3
    # BalanceLock is the persistent audit record for every locked C3 amount.
    #
    # When a payer accepts a C3-priced offer, or when a peer platform requests
    # a lock ahead of a cross-platform settlement, a BalanceLock is created and
    # its lock_ref is returned to the caller.  The lock_ref must be included in
    # the subsequent settlement payload to verify the chain of custody.
    #
    # Locks expire automatically after 24 hours via C3::ExpireBalanceLocksJob.
    # An expired lock releases the reserved C3 back to the payer's available
    # balance — the value is never lost.
    class BalanceLock < ApplicationRecord
      self.table_name = 'better_together_c3_balance_locks'

      STATUSES        = %w[pending settled released expired].freeze
      DEFAULT_TTL     = 24.hours

      belongs_to :balance, class_name: 'BetterTogether::C3::Balance'
      belongs_to :source_platform, class_name: 'BetterTogether::Platform', optional: true

      before_validation :generate_lock_ref, on: :create
      before_validation :set_expiry,        on: :create

      validates :lock_ref,     presence: true, uniqueness: true
      validates :millitokens,  numericality: {
        greater_than: 0,
        less_than_or_equal_to: BetterTogether::C3::Token::MAX_SINGLE_TRANSACTION_MILLITOKENS
      }
      validates :expires_at,   presence: true
      validates :status,       inclusion: { in: STATUSES }

      scope :pending,  -> { where(status: 'pending') }
      scope :expired,  -> { pending.where(arel_table[:expires_at].lt(Time.current)) }
      scope :active,   -> { pending.where(arel_table[:expires_at].gteq(Time.current)) }

      # Mark this lock as settled (C3 was transferred via settle_to!)
      def settle!
        update!(status: 'settled', settled_at: Time.current)
      end

      # Mark this lock as released (payer explicitly cancelled)
      def release!
        update!(status: 'released', settled_at: Time.current)
      end

      # Mark this lock as expired and return the C3 to the payer's balance.
      # Called by C3::ExpireBalanceLocksJob.
      def expire!
        return unless status == 'pending'

        unlock_exact_millitokens!
        update!(status: 'expired', settled_at: Time.current)
      end

      private

      def unlock_exact_millitokens!
        unlock_method = balance.method(:unlock_millitokens!)
        keyword_parameters = unlock_method.parameters.select { |kind, _name| %i[key keyreq keyrest].include?(kind) }
        accepts_lock_ref = keyword_parameters.any? { |_kind, name| name == :lock_ref } ||
                           keyword_parameters.any? { |kind, _name| kind == :keyrest }

        if accepts_lock_ref
          balance.unlock_millitokens!(millitokens, lock_ref: lock_ref)
        else
          balance.unlock_millitokens!(millitokens)
        end
      end
      def generate_lock_ref
        self.lock_ref ||= SecureRandom.uuid
      end

      def set_expiry
        self.expires_at ||= DEFAULT_TTL.from_now
      end
    end
  end
end
