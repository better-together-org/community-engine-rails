# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # A payer moves a subscription Community Engine renews to another recurring price of the platform (another plan's, or the
      # same plan's other interval), and chooses when:
      #
      # * **From the next period** (`request`): no money moves now. The next invoice is made for the new plan at its price, and
      #   what the plan includes is brought in line then (see `apply`). Until then nothing changes, and it can be withdrawn.
      # * **Now** (`now`): the rest of the paid period is prorated by the days left. A cheaper plan changes at once and the
      #   difference comes back as store credit. A dearer plan is invoiced for the difference and changes when that is paid
      #   (see `paid`); until then the subscriber keeps the plan they have, and can withdraw.
      #
      # A move now needs the same schedule (interval and count) and currency, so the period anchor stays valid. A move from the next
      # period may also change the interval of the same plan (monthly to yearly): the periods then count from the end of this one.
      # A move to a plan with smaller allowances is refused while what the holder uses is above what the new plan would allow.
      class ChangePlan
        # Why a move was refused; `code` is a key under `subscriptions.plan_change_refused`.
        class Refused < StandardError
          attr_reader :code

          def initialize(code)
            @code = code
            super(code.to_s)
          end
        end

        # What a move now does: `:credited` or `:invoiced` (with the invoice) or `:no_charge`; `amount_cents` is the prorated difference.
        Outcome = Struct.new(:mode, :amount_cents, :order)

        def self.request(term:, price: nil, plan: nil) = new(term:).request(price || plan.current_price)
        def self.now(term:, price: nil, plan: nil) = new(term:).now(price || plan.current_price)

        def self.withdraw(term:)
          order = term.pending_plan_order
          term.update!(pending_plan: nil, pending_price: nil, pending_plan_requested_at: nil, pending_plan_order: nil)
          Orders::Cancel.call(order) if order&.can_become?('cancelled') && order.net_paid_cents.zero?
          term
        rescue Orders::Cancel::Refused
          term
        end

        # The invoice for a move now was paid: the plan changes.
        def self.paid(term:, order:)
          return term unless term.pending_plan_order_id == order.id && term.pending_price

          term.with_lock { switch(term, term.pending_price) }
          Entitlements::Sync.subscription(term)
          term
        end

        # The prorated difference for a move to this plan right now, in cents (negative when it is cheaper).
        def self.prorated_cents(term, price, now: Time.current)
          subscription = term.pay_subscription
          start = subscription.current_period_start
          finish = subscription.current_period_end
          return 0 unless start && finish && finish > start

          left = ((finish - [now, start].max) / (finish - start)).clamp(0.0, 1.0)
          ((price.amount_cents - term.unit_amount_cents) * left).round
        end

        # The prices this subscription could move to (from the next period): every active recurring price of the platform's
        # listed plans, and the other intervals of the plan the subscriber is on.
        def self.options(term) = PlanChangeCheck.options(term)

        # Called when the next period is about to start: makes the chosen plan the subscription's plan.
        def self.apply(term)
          price = term.pending_price
          return term unless price

          term.with_lock { switch(term, price, next_sequence: (term.periods.last&.sequence || -1) + 1) }
          Entitlements::Sync.subscription(term)
          term
        end

        # An entitlement's plan is fixed once made; a plan change is the one time it moves, so it is moved here.
        # A new interval starts counting at `next_sequence`, from where the last period ended.
        def self.switch(term, price, next_sequence: nil)
          Thread.current[:billing_plan_change] = true
          plan = price.product
          term.update!(plan:, price:, unit_amount_cents: price.amount_cents, currency: price.currency, pending_plan: nil, pending_price: nil,
                       pending_plan_requested_at: nil, pending_plan_order: nil, **reanchor(term, price, next_sequence))
          Entitlement.where(pay_subscription_id: term.pay_subscription_id).update_all(product_id: plan.id) # rubocop:disable Rails/SkipsModelValidations
        ensure
          Thread.current[:billing_plan_change] = nil
        end

        def self.reanchor(term, price, next_sequence)
          return {} if next_sequence.nil? || (price.interval == term.price.interval && price.interval_count == term.price.interval_count)

          { anchor_at: term.period_start(next_sequence), anchor_sequence: next_sequence }
        end

        def initialize(term:)
          @term = term
        end

        def request(price)
          code = refusal(price)
          raise Refused, code if code

          term.update!(pending_plan: price.product, pending_price: price, pending_plan_requested_at: Time.current)
          term
        end

        # Moves to the plan straight away, prorated; see the class comment.
        def now(price)
          code = refusal(price, now: true)
          raise Refused, code if code

          cents = self.class.prorated_cents(term, price)
          return move_now(price, cents, credit: nil) if cents <= 0

          invoice(price, cents)
        end

        # Why a move to this price is not possible, or nil.
        def refusal(price, now: false) = PlanChangeCheck.new(term).refusal(price, now:)

        private

        attr_reader :term

        # A cheaper (or equal) plan: it changes at once, and what was paid for the rest of the period and is no longer owed comes back.
        def move_now(price, cents, credit:)
          term.with_lock { self.class.switch(term, price) }
          Entitlements::Sync.subscription(term)
          grant_credit(-cents) if cents.negative?
          Outcome.new(cents.negative? ? :credited : :no_charge, cents.abs, credit)
        end

        def grant_credit(cents)
          Credit::Grant.call(platform: term.platform, holder: term.payer, amount_cents: cents, currency: term.currency, origin: 'adjustment',
                             idempotency_key: "plan_change:#{term.id}:#{term.pay_subscription.current_period_end.to_i}:#{term.price_id}",
                             note: I18n.t('better_together.billing.subscriptions.plan_change_credit_note'))
        end

        # A dearer plan: the difference is invoiced, and the plan changes when it is paid.
        def invoice(price, cents)
          order = Orders::Place.call(**invoice_attributes(price, cents))
          term.update!(pending_plan: price.product, pending_price: price, pending_plan_requested_at: Time.current, pending_plan_order: order)
          Outcome.new(:invoiced, cents, order)
        end

        def invoice_attributes(price, cents)
          { **invoice_parties, purpose: 'subscription', renewal: true, payment_method: method_to_open,
                               line_items: [{ purchasable: price, quantity: 1, unit_amount_cents: cents }],
                               tax_address: GenerateRenewal.new(term:).tax_address,
                               expires_at: [term.pay_subscription.current_period_end, 3.days.from_now].max }
        end

        def invoice_parties
          { platform: term.platform, buyer: term.payer, signer: term.payer, subject: term, on_behalf_of: term.beneficiary }
        end

        def method_to_open = (term.payment_method unless Billing.internal_method?(term.payment_method))
      end
    end
  end
end
