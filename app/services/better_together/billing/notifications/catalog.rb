# frozen_string_literal: true

module BetterTogether
  module Billing
    module Notifications
      # Who is told what. Each kind lists the audiences that hear about it:
      #
      #   buyer     the person who placed the order
      #   seller    the people who manage billing for the platform that sold it
      #   operator  the same people, for something about how billing itself is working
      #
      # `critical` kinds are always shown in the app and emailed even to a person who turned
      # emails off: a failed payment, a payment that needs their action, a dispute, a changed
      # payment destination, a broken pipeline. Everything else follows the person's choice.
      module Catalog
        KINDS = {
          'order_placed' => { audiences: %i[buyer seller] },
          'order_paid' => { audiences: %i[buyer seller] },
          'order_cancelled' => { audiences: %i[buyer seller] },
          'order_expired' => { audiences: %i[buyer seller] },
          'payment_succeeded' => { audiences: %i[buyer] },
          'payment_failed' => { audiences: %i[buyer], critical: true },
          'payment_action_required' => { audiences: %i[buyer], critical: true },
          'refund_issued' => { audiences: %i[buyer seller] },
          'refund_recorded' => { audiences: %i[buyer] },
          'payment_claimed' => { audiences: %i[seller] },
          'payment_confirmed' => { audiences: %i[buyer] },
          'payment_rejected' => { audiences: %i[buyer] },
          'payment_place_gone' => { audiences: %i[buyer seller] },
          'cheque_received' => { audiences: %i[buyer] },
          'cheque_cleared' => { audiences: %i[buyer] },
          'cheque_bounced' => { audiences: %i[buyer seller], critical: true },
          'confirmation_reminder' => { audiences: %i[seller] },
          'hold_expiring' => { audiences: %i[buyer], critical: true },
          'subscription_renewing' => { audiences: %i[buyer] },
          'subscription_canceled' => { audiences: %i[buyer seller] },
          'trial_ending' => { audiences: %i[buyer] },
          'trial_ended' => { audiences: %i[buyer] },
          'dispute_opened' => { audiences: %i[seller], critical: true },
          'dispute_resolved' => { audiences: %i[seller] },
          'settings_changed' => { audiences: %i[operator], critical: true },
          'event_dead_lettered' => { audiences: %i[operator], critical: true },
          'plan_sync_failed' => { audiences: %i[operator], critical: true }
        }.freeze

        def self.kind?(kind) = KINDS.key?(kind.to_s)

        def self.audiences(kind) = KINDS.fetch(kind.to_s).fetch(:audiences)

        def self.critical?(kind) = KINDS.fetch(kind.to_s, {}).fetch(:critical, false)
      end
    end
  end
end
