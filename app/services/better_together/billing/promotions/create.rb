# frozen_string_literal: true

module BetterTogether
  module Billing
    module Promotions
      # Makes a promotion and its code. The code is in the result and nowhere else: it is shown to the
      # steward once and only its keyed digest is kept (see Promotion).
      #
      #   result = Promotions::Create.call(platform:, actor: steward, name: 'Spring drive', amount_cents: 1500, currency: 'USD')
      #   result.code       # => "K7QM-2XPD-9TRW-HN4C", shown once
      #   result.promotion
      class Create
        Result = Data.define(:promotion, :code)

        class Refused < StandardError; end

        ATTEMPTS = 3
        LIMITS = %i[credit_expires_after_days purposes starts_at ends_at max_redemptions new_members_only].freeze

        def self.call(...) = new(...).call

        def initialize(platform:, actor:, name:, amount_cents:, currency:, **limits) # rubocop:disable Metrics/ParameterLists
          @platform = platform
          @attributes = { name:, amount_cents:, currency:, created_by: actor, **limits.slice(*LIMITS) }
        end

        def call
          ATTEMPTS.times do
            result = attempt
            return result if result
          end
          raise Refused, 'a code could not be made'
        rescue ActiveRecord::RecordInvalid => e
          raise Refused, e.record.errors.full_messages.to_sentence
        end

        private

        attr_reader :platform, :attributes

        # One try with a new code; nil when it collided with another (the digest is unique per platform).
        def attempt
          code = Promotion.generate_code
          promotion = platform.billing_promotions.build(attributes.merge(code_digest: Promotion.digest_for(code)))
          return Result.new(promotion: promotion.tap(&:save!), code:) if promotion.valid? || !digest_taken?(promotion)

          nil
        rescue ActiveRecord::RecordNotUnique
          nil
        end

        def digest_taken?(promotion) = promotion.errors.of_kind?(:code_digest, :taken)
      end
    end
  end
end
