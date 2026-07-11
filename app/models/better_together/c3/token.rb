# frozen_string_literal: true

module BetterTogether
  module C3
    # Token records a single C3 contribution event.
    # Earner is the Person (or future AgentActor) whose node performed the work.
    # C3 amounts are stored as millitokens (1 Tree Seed = 1_000 millitokens) for integer arithmetic.
    #
    # NOTE: C3 does NOT influence governance votes — one member, one vote (co-op principle).
    class Token < ApplicationRecord
      self.table_name = 'better_together_c3_tokens'

      MILLITOKEN_SCALE = 1_000 # 1 Tree Seed = 1_000 millitokens

      # Maximum millitokens in a single transaction (10,000 Tree Seeds).
      # Prevents overflow and limits blast radius of malformed or malicious payloads.
      MAX_SINGLE_TRANSACTION_MILLITOKENS = 10_000 * MILLITOKEN_SCALE

      CONTRIBUTION_TYPES = BetterTogether::C3::ExchangeRate::CONTRIBUTION_TYPES
      TOKEN_STATUSES = %w[pending confirmed disputed settled].freeze

      # Deterministic encryption so the for_source scope and duplicate-check in
      # ContributionsController (Token.exists?(source_ref: ...)) continue to work.
      encrypts :source_ref, deterministic: true

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

      # Safe conversion: C3 Tree Seed amount (as string/decimal) → millitokens (integer)
      # Uses BigDecimal to avoid floating-point precision loss during conversion.
      # Returns exact integer millitokens value, safe for ledger operations.
      #
      # @param c3_amount [String, Numeric] Tree Seed amount (e.g., "1.5", 1.5, 1)
      # @return [Integer] Millitokens value
      # @raise [ArgumentError] if amount is negative, exceeds max, or has more than 3 decimal places
      def self.c3_to_millitokens(c3_amount)
        decimal_amount = BigDecimal(c3_amount.to_s)
        raise ArgumentError, 'C3 amount must be non-negative' if decimal_amount.negative?

        validate_decimal_places!(c3_amount)

        millitokens = (decimal_amount * MILLITOKEN_SCALE).to_i
        validate_max_transaction!(millitokens)

        millitokens
      rescue ArgumentError
        raise
      rescue StandardError => e
        raise ArgumentError, "Invalid C3 amount '#{c3_amount}': #{e.message}"
      end

      # Validates that the amount has at most 3 decimal places.
      # @param c3_amount [String, Numeric] Amount to validate
      # @raise [ArgumentError] if amount has more than 3 decimal places
      private_class_method def self.validate_decimal_places!(c3_amount)
        string_repr = c3_amount.to_s.strip
        return unless string_repr.include?('.')

        # Trailing zeros carry no precision (e.g. "1.2000" is exactly "1.2"), so strip
        # them before measuring significant decimal digits.
        decimal_part = string_repr.split('.')[1].sub(/0+\z/, '')
        # MILLITOKEN_SCALE is 1_000 (3 decimal places of resolution) — a 4th
        # significant decimal digit is sub-millitoken and would be silently truncated
        # by (decimal_amount * MILLITOKEN_SCALE).to_i below, losing precision in a
        # financial calculation. Reject it outright instead.
        return unless decimal_part.length > 3

        raise ArgumentError, 'C3 amount must have at most 3 decimal places'
      end

      # Validates that millitokens doesn't exceed the maximum transaction amount.
      # @param millitokens [Integer] Amount in millitokens
      # @raise [ArgumentError] if exceeds MAX_SINGLE_TRANSACTION_MILLITOKENS
      private_class_method def self.validate_max_transaction!(millitokens)
        return unless millitokens > MAX_SINGLE_TRANSACTION_MILLITOKENS

        raise ArgumentError,
              "C3 amount exceeds maximum (#{millitokens} > #{MAX_SINGLE_TRANSACTION_MILLITOKENS} millitokens)"
      end

      # Safe conversion: millitokens (integer) → C3 Tree Seed amount (float, for display only)
      # Returns float representation rounded to 4 decimal places for UI display.
      # NEVER use this result for subsequent calculations; use millitokens directly.
      #
      # @param millitokens [Integer] Millitokens value
      # @return [Float] Tree Seed amount, rounded to 4 decimals
      def self.millitokens_to_c3(millitokens)
        (millitokens.to_f / MILLITOKEN_SCALE).round(4)
      end

      # Safe conversion: millitokens (integer) → C3 Tree Seed amount (BigDecimal, for precise API responses)
      # Returns exact BigDecimal representation, suitable for JSON serialization with precision.
      #
      # @param millitokens [Integer] Millitokens value
      # @return [BigDecimal] Tree Seed amount as exact decimal
      def self.millitokens_to_c3_decimal(millitokens)
        BigDecimal(millitokens.to_s) / MILLITOKEN_SCALE
      end

      # Convert to/from C3 decimal amount
      # NOTE: Deprecated for new code. Use c3_to_millitokens class method for precision.
      def c3_amount
        c3_millitokens.to_f / MILLITOKEN_SCALE
      end

      def c3_amount=(amount)
        # Use BigDecimal internally to avoid float precision loss
        self.c3_millitokens = self.class.c3_to_millitokens(amount)
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
