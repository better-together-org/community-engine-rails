# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # Moves a subscription Community Engine renews through the time-based states of Pay's own vocabulary:
      #
      # * `active`  -> `past_due` when its period ended with no renewal paid. The **grace** begins: everything
      #   works and the payer is warned. (This is the dunning window; Pay's own "grace period" means something
      #   else, a cancelled subscription still paid through its period.)
      # * `past_due` -> `unpaid` when the grace ends, with `ends_at` set to that moment. The period lapses.
      #   The invoice stays open until its hold runs out, and paying it later starts the subscription again
      #   (see Renew); nothing is ever deleted.
      # * a subscription cancelled at the end of its period becomes `canceled` once that moment passes.
      #
      # Safe to repeat, and each step happens once.
      class Advance
        def self.call(...) = new(...).call

        def initialize(term:, now: Time.current)
          @term = term
          @now = now
        end

        def call
          term.with_lock { step }
          subscription
        end

        private

        attr_reader :term, :now

        def subscription = term.pay_subscription
        def latest_period = term.periods.last

        def step
          if subscription.ends_at.present? then finish_ended
          elsif running_past_its_period? then overdue
          elsif grace_over? then lapse
          end
        end

        def running_past_its_period? = subscription.status == 'active' && subscription.current_period_end <= now

        def grace_over? = subscription.status == 'past_due' && term.grace_ends_at.present? && term.grace_ends_at <= now

        # A cancellation that has reached its date. A lapse (`unpaid`) is already final.
        def finish_ended
          return unless subscription.ends_at <= now && subscription.status == 'active'

          subscription.update!(status: :canceled)
        end

        def overdue
          term.update!(grace_ends_at: subscription.current_period_end + term.grace_days.days)
          return lapse if term.grace_ends_at <= now

          subscription.update!(status: :past_due)
          tell_overdue
        end

        def tell_overdue
          key = "overdue:#{term.id}:#{subscription.current_period_end.to_i}"
          Notifications.deliver('renewal_overdue', subject: latest_period || term, dedupe_key: key)
        end

        def lapse
          subscription.update!(status: :unpaid, ends_at: term.grace_ends_at)
          latest_period&.update!(status: 'lapsed') if latest_period&.unsettled?
          Notifications.deliver('subscription_canceled', subject: term, dedupe_key: "lapsed:#{term.id}:#{term.grace_ends_at.to_i}")
        end
      end
    end
  end
end
