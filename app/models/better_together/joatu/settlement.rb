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
      validates :c3_millitokens, numericality: { greater_than_or_equal_to: 0 }
      validates :agreement_id, uniqueness: { message: 'already has a settlement record' }

      scope :pending,   -> { where(status: 'pending') }
      scope :completed, -> { where(status: 'completed') }

      def c3_amount
        c3_millitokens.to_f / BetterTogether::C3::Token::MILLITOKEN_SCALE
      end

      # Complete the settlement: transfer locked C3 from payer to recipient and mint a Token.
      # Called from Agreement#fulfill! inside a transaction.
      def complete!(payer_balance:, recipient_balance:) # rubocop:todo Metrics/MethodLength
        raise ActiveRecord::RecordInvalid, self unless status == 'pending'

        token = nil

        transaction do
          payer_balance.settle_to!(recipient_balance, c3_amount)

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

        token
      end

      # Cancel the settlement: return locked C3 to payer.
      # Called when an accepted agreement is cancelled.
      def cancel!(payer_balance:)
        raise ActiveRecord::RecordInvalid, self unless status == 'pending'

        transaction do
          payer_balance.unlock!(c3_amount) if c3_millitokens.positive?
          update!(status: 'cancelled', completed_at: Time.current)
        end
      end

      def to_s
        "Settlement #{id&.first(8)} #{status} #{c3_amount} C3"
      end
    end
  end
end
