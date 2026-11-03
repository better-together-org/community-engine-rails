# frozen_string_literal: true

module BetterTogether
  module Billing
    module Credit
      # Gives a person credit. A steward may grant it to someone else, never to themselves; a promotion or a
      # refund is granted by the system (no `actor`) under its own origin.
      #
      # Repeating a request with the same `idempotency_key` returns the lot it already made.
      class Grant
        def self.call(...) = new(...).call

        def initialize(platform:, holder:, amount_cents:, currency:, origin:, idempotency_key:, actor: nil, # rubocop:disable Metrics/ParameterLists
                       expires_at: nil, purposes: [], promotional: false, note: nil, source: nil)
          @platform = platform
          @holder = holder
          @amount_cents = amount_cents.to_i
          @currency = currency.to_s
          @origin = origin.to_s
          @idempotency_key = idempotency_key.to_s
          @actor = actor
          @lot_attributes = { origin:, amount_cents:, expires_at:, purposes:, promotional:, note: }
          @source = source
        end

        # The lot.
        def call
          check!
          account.with_lock do
            entry = Credit.entries_for(account, idempotency_key).first
            next entry.lot if entry

            grant
          end
        rescue ActiveRecord::RecordInvalid => e
          raise Refused, e.record.errors.full_messages.to_sentence
        end

        private

        attr_reader :platform, :holder, :amount_cents, :currency, :origin, :idempotency_key, :actor, :lot_attributes, :source

        def account = @account ||= Credit.account_for(platform:, holder:, currency:)

        def grant
          lot = account.lots.create!(platform_id: platform.id, granted_by: actor, remaining_cents: amount_cents, **lot_attributes)
          Credit.post!(account:, lot:, kind: 'grant', amount_cents:, transaction_key: idempotency_key, actor:, source:, note: lot.note)
          lot
        end

        def check!
          problem = (problems.find { |condition, _| condition } || []).last
          raise Refused, problem if problem
        end

        def problems
          [[idempotency_key.blank?, 'a grant needs a key'],
           [!amount_cents.positive?, 'a grant must be more than nothing'],
           [actor.present? && actor == holder, 'nobody can give themselves credit'],
           [CreditLot::ORIGINS.exclude?(origin), 'that is not a way credit is granted'],
           [origin == 'steward_grant' && actor.nil?, 'a steward grant needs the steward who made it']]
        end
      end
    end
  end
end
