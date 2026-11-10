# frozen_string_literal: true

module BetterTogether
  module Billing
    module Entitlements
      # What a Pay subscription gives right now. A **pure function over Pay's own vocabulary** (the subscription's
      # status, period and end), the same for a subscription Community Engine renews and one a processor renews,
      # so there is one derivation for every way of paying. It names `STATUSES`, the statuses Pay uses, and treats any other as lapsed.
      #
      #   status                        result
      #   trialing, active              active until the period (or trial, or the date it ends) is over;
      #                                 lapsed once an end date has passed
      #   past_due                      grace until the terms' grace ends (the plan's grace days after the
      #                                 period), lapsed after
      #   unpaid, canceled,
      #   incomplete_expired, paused    lapsed (the processor is the authority for a processor's subscription)
      #   incomplete                    pending: nothing is given yet
      #   any other status              lapsed, with a logged warning (a processor can report one Pay does not list)
      #
      # Pay's own `on_grace_period?` is a cancelled subscription still paid through its period; the unpaid window
      # here is the dunning window (`past_due`). They are different things.
      module State
        Result = Data.define(:status, :ends_at, :grace_ends_at) do
          def live? = %w[active grace].include?(status)
        end

        LAPSED_STATUSES = %w[unpaid canceled incomplete_expired paused].freeze
        STATUSES = (%w[incomplete trialing active past_due] + LAPSED_STATUSES).freeze

        module_function

        def call(subscription, term = nil, now: Time.current)
          status = subscription.status
          return Result.new(status: 'pending', ends_at: nil, grace_ends_at: nil) if status == 'incomplete'
          return lapsed(subscription) if LAPSED_STATUSES.include?(status)
          return past_due(subscription, term, now) if status == 'past_due'
          return running(subscription, now) if %w[trialing active].include?(status)

          unknown(subscription)
        end

        # A processor can report a status Pay does not list (Braintree `expired`, Lemon Squeezy `expired`).
        # Access is never kept on one: it is lapsed, and the status is logged so it can be named above.
        def unknown(subscription)
          Rails.logger.warn("[Billing] unknown subscription status #{subscription.status.inspect}, treating it as lapsed")
          lapsed(subscription)
        end

        def running(subscription, now)
          ends = ending(subscription)
          return lapsed(subscription) if subscription.ends_at.present? && subscription.ends_at <= now

          Result.new(status: 'active', ends_at: ends, grace_ends_at: nil)
        end

        # When access stops if nothing more is paid: the end date if one was set, else the end of the period
        # (or of the trial, while on one).
        def ending(subscription)
          return subscription.ends_at if subscription.ends_at.present?
          return subscription.trial_ends_at if subscription.on_trial? && subscription.trial_ends_at.present?

          subscription.current_period_end
        end

        def past_due(subscription, term, now)
          grace_ends = term&.grace_ends_at || subscription.current_period_end
          return lapsed(subscription) if grace_ends.present? && grace_ends <= now

          Result.new(status: 'grace', ends_at: subscription.current_period_end, grace_ends_at: grace_ends)
        end

        def lapsed(subscription)
          Result.new(status: 'lapsed', ends_at: subscription.ends_at || subscription.current_period_end, grace_ends_at: nil)
        end
      end
    end
  end
end
