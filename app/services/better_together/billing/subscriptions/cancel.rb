# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # Cancels a subscription Community Engine renews: at the end of the period already paid for (the
      # default, Pay's `cancel`), or now (`now: true`). Nothing already paid is taken back. Any renewal invoice
      # nobody has paid is cancelled with it, and its period lapses. Safe to repeat.
      class Cancel
        def self.call(...) = new(...).call

        def initialize(term:, now: false, by: nil)
          @term = term
          @now = now
          @by = by
        end

        def call
          term.with_lock do
            next subscription if finished?

            end_subscription
            release_invoice
            tell
            subscription
          end
        end

        private

        attr_reader :term, :now, :by

        def subscription = term.pay_subscription

        def finished? = subscription.status == 'canceled' || (subscription.ends_at.present? && !now)

        def end_subscription
          now ? subscription.cancel_now! : subscription.cancel
          subscription.update!(status: :canceled) if subscription.ends_at <= Time.current
        end

        def tell
          Notifications.deliver('subscription_canceled', subject: term, actor: by,
                                                         dedupe_key: "canceled:#{term.id}:#{subscription.ends_at.to_i}")
        end

        # The unpaid renewal invoice, if there is one, goes with the subscription.
        def release_invoice
          period = term.periods.unsettled.last
          return unless period

          cancel_order(period.order)
          period.update!(status: 'lapsed')
        end

        def cancel_order(order)
          Orders::Cancel.call(order) if order&.open?
        rescue Orders::Cancel::Refused
          nil # money is already against it; a person deals with that
        end
      end
    end
  end
end
