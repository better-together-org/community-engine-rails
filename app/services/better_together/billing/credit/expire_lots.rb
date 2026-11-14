# frozen_string_literal: true

module BetterTogether
  module Billing
    module Credit
      # Lets credit past its date go: each lot that has expired with something left is emptied, with an
      # `expire` entry for what was lost. Safe to repeat; a lot already emptied is skipped.
      class ExpireLots
        def self.call(...) = new(...).call

        def initialize(now: Time.current, platform: nil)
          @now = now
          @platform = platform
        end

        # The number of lots expired.
        def call
          scope.find_each.count { |lot| expire(lot) }
        end

        private

        attr_reader :now, :platform

        def scope
          lots = CreditLot.lapsed(now)
          platform ? lots.where(platform_id: platform.id) : lots
        end

        def expire(lot)
          account = lot.account
          account.with_lock do
            lot.reload
            next false unless lot.remaining_cents.positive? && lot.expired?(now)

            Credit.post!(account:, lot:, kind: 'expire', amount_cents: -lot.remaining_cents, transaction_key: "expire:#{lot.id}",
                         note: nil)
            true
          end
        end
      end
    end
  end
end
