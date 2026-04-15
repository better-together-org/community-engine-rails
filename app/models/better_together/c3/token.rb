# frozen_string_literal: true

module BetterTogether
  module C3
    # Token records a single C3 contribution event.
    # Earner is the Person (or future AgentActor) whose node performed the work.
    # C3 amounts are stored as millitokens (1 C3 = 10_000 millitokens) for integer arithmetic.
    #
    # NOTE: C3 does NOT influence governance votes — one member, one vote (co-op principle).
    class Token < ApplicationRecord
      self.table_name = 'better_together_c3_tokens'

      MILLITOKEN_SCALE = 10_000 # 1 C3 = 10_000 millitokens

      # Maximum millitokens in a single transaction (10,000 C3 / Tree Seeds).
      # Prevents overflow and limits blast radius of malformed or malicious payloads.
      MAX_SINGLE_TRANSACTION_MILLITOKENS = 10_000 * MILLITOKEN_SCALE

      CONTRIBUTION_TYPES = BetterTogether::C3::ExchangeRate::CONTRIBUTION_TYPES
      TOKEN_STATUSES = %w[pending confirmed disputed settled].freeze

      enum :contribution_type, CONTRIBUTION_TYPES

      belongs_to :earner, polymorphic: true
      belongs_to :community, class_name: 'BetterTogether::Community', optional: true
      # origin_platform_id is nil for tokens minted locally; set for tokens received via federation
      belongs_to :origin_platform, class_name: 'BetterTogether::Platform', optional: true

      validates :earner, :contribution_type, :source_ref, :source_system, presence: true
      validates :source_ref, uniqueness: { scope: :source_system }
      validates :c3_millitokens, numericality: {
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: MAX_SINGLE_TRANSACTION_MILLITOKENS
      }
      validates :status, inclusion: { in: TOKEN_STATUSES }

      scope :confirmed,  -> { where(status: 'confirmed') }
      scope :pending,    -> { where(status: 'pending') }
      scope :for_source, ->(system, ref) { where(source_system: system, source_ref: ref) }
      scope :local,      -> { where(federated: false) }
      scope :federated,  -> { where(federated: true) }

      # Convert to/from C3 decimal amount
      def c3_amount
        c3_millitokens.to_f / MILLITOKEN_SCALE
      end

      def c3_amount=(amount)
        self.c3_millitokens = (amount.to_f * MILLITOKEN_SCALE).round
      end

      def confirm!
        update!(status: 'confirmed', confirmed_at: Time.current)
      end

      def to_s
        "#{contribution_type_name} #{c3_amount} C3 (#{source_ref})"
      end
    end
  end
end
