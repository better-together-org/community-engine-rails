# frozen_string_literal: true

module BetterTogether
  module Borgberry
    module Decorations
      # Prepended onto BetterTogether::Joatu::Agreement by Borgberry::Engine's
      # model registry (config.to_prepare) when this extension is bundled.
      # Moved out of core Agreement as part of the C3/Fleet extraction — core
      # Agreement calls the after_accept_side_effects/complete_pending_settlement!/
      # cancel_pending_settlement! hooks unconditionally as no-ops; this module
      # overrides them via `super`, which requires `prepend` rather than `include`
      # (Ruby checks prepended modules before the class's own method definitions).
      module JoatuAgreement
        extend ActiveSupport::Concern

        # `included do` would never run here — this module is applied via `prepend`
        # (see the class comment above), and ActiveSupport::Concern only fires
        # `included do` blocks for `include`. `prepended do` is the prepend-specific
        # equivalent, needed so the has_one :settlement association actually gets
        # declared on the class.
        prepended do
          has_one :settlement, class_name: 'BetterTogether::Joatu::Settlement',
                               dependent: :destroy
        end

        def after_accept_side_effects
          super
          create_settlement_if_c3_priced!
        end

        def complete_pending_settlement!
          super
          return unless settlement&.status == 'pending' && settlement.c3_millitokens.positive?

          payer_balance = BetterTogether::C3::Balance.find_by!(holder: settlement.payer)
          recipient_balance = BetterTogether::C3::Balance.find_or_create_by!(holder: settlement.recipient)
          settlement.complete!(payer_balance:, recipient_balance:)
        end

        def cancel_pending_settlement!
          super
          return unless settlement&.status == 'pending'

          payer_balance = BetterTogether::C3::Balance.find_by!(holder: settlement.payer)
          settlement.cancel!(payer_balance: payer_balance)
        end

        private

        # Create a pending Settlement and lock C3 from the payer (request creator)
        # when the offer carries a C3 price. No-op if the offer has no C3 price.
        #
        # The lock_ref returned by Balance#lock_millitokens! is stored on the Settlement so that
        # Settlement#complete! and Settlement#cancel! can finalise the BalanceLock record
        # (marking it settled or released) rather than leaving it pending until expiry.
        def create_settlement_if_c3_priced! # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
          price_millitokens = offer.try(:c3_price_millitokens).to_i
          return unless price_millitokens.positive?

          payer = request.creator
          return unless payer

          payer_balance = BetterTogether::C3::Balance.find_or_create_by!(holder: payer)
          # Use lock_millitokens! to avoid float conversion round-trip
          # (price_millitokens is already an integer from the database)
          captured_lock_ref = payer_balance.lock_millitokens!(
            price_millitokens,
            agreement_ref: id
          )

          new_settlement = create_settlement!(
            payer: payer,
            recipient: offer.creator,
            c3_millitokens: price_millitokens,
            lock_ref: captured_lock_ref,
            status: 'pending'
          )

          BetterTogether::C3::SettlementNotifier
            .with(settlement: new_settlement, event_type: :c3_locked)
            .deliver_later([payer, offer.creator].compact.uniq)
        end
      end
    end
  end
end
