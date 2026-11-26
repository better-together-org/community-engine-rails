# frozen_string_literal: true

module BetterTogether
  module Billing
    module Promotions
      # A person turns a code into store credit.
      #
      # **There is one answer to every failure.** An unknown code, one that has ended, run out, is switched
      # off, is not yet open, is for new members only, or was already used by this person all raise the same
      # Invalid with the same words, so a failed attempt tells nobody which codes exist. Failures are also
      # counted per person and platform: after MAX_FAILURES in WINDOW the person is refused outright (still
      # with the same answer, and without looking anything up) until the window passes. Callers should add a
      # per-address throttle too (see config/initializers/rack_attack.rb).
      #
      # The promotion is locked while the redemption is made, so a cap of N is N however many people redeem
      # at the same moment, and the database allows one redemption per person and promotion.
      #
      #   lot = Promotions::Redeem.call(platform:, person:, code: 'K7QM-2XPD-9TRW-HN4C')
      class Redeem
        MESSAGE = 'that code is not valid'
        MAX_FAILURES = 10
        WINDOW = 1.hour

        # The one answer to every failure.
        class Invalid < StandardError
          def initialize = super(MESSAGE)
        end

        def self.call(...) = new(...).call

        def initialize(platform:, person:, code:, now: Time.current)
          @platform = platform
          @person = person
          @code = code
          @now = now
        end

        # The credit lot the redemption made.
        def call
          raise Invalid if locked_out?

          lot = promotion && redeem
          return lot if lot

          count_failure
          raise Invalid
        end

        private

        attr_reader :platform, :person, :code, :now

        def promotion
          return if Promotion.normalize(code).length != Promotion::CODE_LENGTH

          @promotion ||= platform.billing_promotions.find_by(code_digest: Promotion.digest_for(code))
        end

        def redeem
          promotion.with_lock do
            next unless eligible?

            lot = grant
            promotion.redemptions.create!(platform_id: platform.id, person:, credit_lot: lot)
            promotion.update!(redemptions_count: promotion.redemptions_count + 1)
            lot
          end
        end

        def eligible?
          promotion.redeemable?(now) && !already_redeemed? && (!promotion.new_members_only? || new_member?)
        end

        def already_redeemed? = promotion.redemptions.exists?(person_id: person.id)

        # Someone who has never paid an order on this platform.
        def new_member? = platform.billing_orders.bought_by(person).where.not(paid_at: nil).none?

        def grant
          Credit::Grant.call(platform:, holder: person, amount_cents: promotion.amount_cents, currency: promotion.currency,
                             origin: 'promotion', promotional: true, purposes: promotion.purposes, note: promotion.name,
                             expires_at:, idempotency_key: "promotion:#{promotion.id}:#{person.id}")
        end

        def expires_at
          days = promotion.credit_expires_after_days
          now + days.days if days
        end

        def failures_key = "billing:promotion_failures:#{platform.id}:#{person.id}"

        def locked_out? = Rails.cache.read(failures_key).to_i >= MAX_FAILURES

        # One atomic increment, so concurrent guesses cannot all read the same count. Needs a shared
        # cache store (Redis or memcached); a null or per-process store cannot hold the count.
        def count_failure
          Rails.cache.increment(failures_key, 1, expires_in: WINDOW, initial: 0)
        end
      end
    end
  end
end
