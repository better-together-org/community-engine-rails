# frozen_string_literal: true

module Pay
  module Local
    # A subscription paid by a way Community Engine settles itself. Pay's own FakeProcessor stores a
    # subscription but its `cancel` ends it at the end of the month, whatever was paid for; here a
    # subscription ends where its paid period ends. Nothing renews it on its own: Community Engine
    # advances it (see #advance!) when the next period is paid.
    #
    # Status follows Pay's vocabulary so its scopes and predicates keep working: `active`, `past_due`
    # (in the dunning window), `unpaid` (lapsed for non-payment) and `canceled`.
    class Subscription < Pay::Subscription
      def self.sync(_processor_id, **)
        # Nothing to fetch: there is no processor to ask.
      end

      def api_record(**)
        self
      end

      # Ends the subscription where the period that was paid for ends.
      def cancel(**)
        return if canceled?

        update!(ends_at: ends_at_for_cancel)
      end

      def cancel_now!(**)
        return if canceled?

        now = Time.current
        update!(status: :canceled, trial_ends_at: (now if trial_ends_at?), ends_at: now)
      end

      def paused? = false

      def pause(**)
        raise NotImplementedError, 'a subscription paid outside a processor cannot be paused'
      end

      def unpause
        raise NotImplementedError, 'a subscription paid outside a processor cannot be paused'
      end

      def resumable? = on_grace_period?

      def resume
        raise Pay::Error, 'You can only resume subscriptions within their grace period.' unless resumable?

        update!(status: :active, ends_at: nil)
      end

      def swap(plan, **)
        update!(processor_plan: plan, ends_at: nil, status: :active)
      end

      def change_quantity(quantity, **)
        update!(quantity:)
      end

      # The next period was paid: it runs from `starts_at` to `ends_at`, and the subscription is active again.
      def advance!(starts_at:, ends_at:)
        update!(current_period_start: starts_at, current_period_end: ends_at, status: :active, ends_at: nil)
      end

      private

      def ends_at_for_cancel
        return trial_ends_at if on_trial?

        current_period_end || Time.current
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_local_subscription, Pay::Local::Subscription
