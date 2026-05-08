# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Settlement is the audit record for a completed C3 value transfer between two parties
    # via an accepted Joatu::Agreement. It bridges the gap between the agreement acceptance
    # (which locks C3 from the payer) and fulfillment (which releases C3 to the recipient).
    #
    # Lifecycle:
    #   pending   — created when agreement is accepted; payer's C3 is locked
    #   completed — created when agreement is fulfilled; C3 transferred to recipient
    #   cancelled — created when agreement is cancelled; locked C3 returned to payer
    class Settlement < ApplicationRecord
      self.table_name = 'better_together_joatu_settlements'

      STATUSES = %w[pending completed cancelled].freeze

      belongs_to :agreement, class_name: 'BetterTogether::Joatu::Agreement'
      belongs_to :payer, polymorphic: true
      belongs_to :recipient, polymorphic: true
      belongs_to :c3_token, class_name: 'BetterTogether::C3::Token', optional: true

      validates :status, presence: true, inclusion: { in: STATUSES }
      validates :c3_millitokens, numericality: {
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: BetterTogether::C3::Token::MAX_SINGLE_TRANSACTION_MILLITOKENS
      }
      validates :agreement_id, uniqueness: { message: :already_settled }

      scope :pending,   -> { where(status: 'pending') }
      scope :completed, -> { where(status: 'completed') }

      def c3_amount
        c3_millitokens.to_f / BetterTogether::C3::Token::MILLITOKEN_SCALE
      end

      # Complete the settlement: transfer locked C3 from payer to recipient and mint a Token.
      # Called from Agreement#fulfill! inside a transaction.
      # lock_ref is read from the settlement record (stored when the lock was created
      # in Agreement#create_settlement_if_c3_priced!) so the BalanceLock is marked settled.
      def complete!(payer_balance:, recipient_balance:) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        assert_pending_with_required_lock!

        token = nil

        transaction do
          with_lock_invariant_errors do
            payer_balance.settle_to!(recipient_balance, c3_amount, lock_ref: lock_ref)
          end

          token = BetterTogether::C3::Token.create!(
            earner: recipient,
            contribution_type: :volunteer,
            contribution_type_name: 'joatu_exchange',
            c3_millitokens: c3_millitokens,
            source_ref: "settlement:#{id}",
            source_system: 'ce_joatu',
            status: 'confirmed',
            emitted_at: Time.current,
            confirmed_at: Time.current
          )

          update!(status: 'completed', c3_token: token, completed_at: Time.current)
        end

        BetterTogether::C3::SettlementNotifier
          .with(settlement: self, event_type: :c3_settled)
          .deliver_later([payer, recipient].compact.uniq)

        token
      end

      # Cancel the settlement: return locked C3 to payer.
      # Called when an accepted agreement is cancelled.
      # lock_ref is used to mark the corresponding BalanceLock as released.
      def cancel!(payer_balance:)
        assert_pending_with_required_lock!

        transaction do
          with_lock_invariant_errors do
            payer_balance.unlock!(c3_amount, lock_ref: lock_ref) if c3_millitokens.positive?
          end
          update!(status: 'cancelled', completed_at: Time.current)
        end

        BetterTogether::C3::SettlementNotifier
          .with(settlement: self, event_type: :c3_lock_released)
          .deliver_later([payer, recipient].compact.uniq)
      end

      def to_s
        "Settlement #{id&.first(8)} #{status} #{c3_amount} C3"
      end

      private

      def assert_pending_with_required_lock!
        return if status == 'pending' && (c3_millitokens.zero? || lock_ref.present?)

        errors.add(:base, 'Settlement must be pending before it can transition') unless status == 'pending'
        errors.add(:lock_ref, 'must be present for locked C3 settlements') if c3_millitokens.positive? && lock_ref.blank?
        raise ActiveRecord::RecordInvalid, self
      end

      def with_lock_invariant_errors
        yield
      rescue BetterTogether::C3::Balance::LockError => e
        errors.add(:lock_ref, e.message)
        raise ActiveRecord::RecordInvalid, self
      end
    end
  end
end
