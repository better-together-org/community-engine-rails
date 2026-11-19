# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # A payer moves a subscription Community Engine renews to another of the platform's plans, and chooses when:
      #
      # * **From the next period** (`request`): no money moves now. The next invoice is made for the new plan at its price, and
      #   what the plan includes is brought in line then (see `apply`). Until then nothing changes, and it can be withdrawn.
      # * **Now** (`now`): the rest of the paid period is prorated by the days left. A cheaper plan changes at once and the
      #   difference comes back as store credit. A dearer plan is invoiced for the difference and changes when that is paid
      #   (see `paid`); until then the subscriber keeps the plan they have, and can withdraw.
      #
      # Only a move to a plan on the same schedule (interval and count) and currency is offered, so the period anchor stays valid.
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

        def self.request(term:, plan:) = new(term:).request(plan)
        def self.now(term:, plan:) = new(term:).now(plan)

        def self.withdraw(term:)
          order = term.pending_plan_order
          term.update!(pending_plan: nil, pending_plan_requested_at: nil, pending_plan_order: nil)
          Orders::Cancel.call(order) if order&.can_become?('cancelled') && order.net_paid_cents.zero?
          term
        rescue Orders::Cancel::Refused
          term
        end

        # The invoice for a move now was paid: the plan changes.
        def self.paid(term:, order:)
          return term unless term.pending_plan_order_id == order.id && term.pending_plan

          term.with_lock { switch(term, term.pending_plan) }
          Entitlements::Sync.subscription(term)
          term
        end

        # The prorated difference for a move to this plan right now, in cents (negative when it is cheaper).
        def self.prorated_cents(term, plan, now: Time.current)
          subscription = term.pay_subscription
          start = subscription.current_period_start
          finish = subscription.current_period_end
          return 0 unless start && finish && finish > start

          left = ((finish - [now, start].max) / (finish - start)).clamp(0.0, 1.0)
          ((plan.amount_cents - term.unit_amount_cents) * left).round
        end

        # The plans this subscription could move to.
        def self.options(term)
          finder = new(term:)
          term.platform.billing_plans.sold_by_platform.active.listed.where.not(id: term.plan_id).select { |plan| finder.refusal(plan).nil? }
        end

        # Called when the next period is about to start: makes the chosen plan the subscription's plan.
        def self.apply(term)
          plan = term.pending_plan
          return term unless plan

          term.with_lock { switch(term, plan) }
          Entitlements::Sync.subscription(term)
          term
        end

        # An entitlement's plan is fixed once made; a plan change is the one time it moves, so it is moved here.
        def self.switch(term, plan)
          Thread.current[:billing_plan_change] = true
          term.update!(plan:, unit_amount_cents: plan.amount_cents, currency: plan.currency, pending_plan: nil, pending_plan_requested_at: nil,
                       pending_plan_order: nil)
          Entitlement.where(pay_subscription_id: term.pay_subscription_id).update_all(plan_id: plan.id) # rubocop:disable Rails/SkipsModelValidations
        ensure
          Thread.current[:billing_plan_change] = nil
        end

        def initialize(term:)
          @term = term
        end

        def request(plan)
          code = refusal(plan)
          raise Refused, code if code

          term.update!(pending_plan: plan, pending_plan_requested_at: Time.current)
          term
        end

        # Moves to the plan straight away, prorated; see the class comment.
        def now(plan)
          code = refusal(plan)
          raise Refused, code if code

          cents = self.class.prorated_cents(term, plan)
          return move_now(plan, cents, credit: nil) if cents <= 0

          invoice(plan, cents)
        end

        # Why a move to this plan is not possible, or nil.
        def refusal(plan) = PlanChangeCheck.new(term).refusal(plan)

        private

        attr_reader :term

        # A cheaper (or equal) plan: it changes at once, and what was paid for the rest of the period and is no longer owed comes back.
        def move_now(plan, cents, credit:)
          term.with_lock { self.class.switch(term, plan) }
          Entitlements::Sync.subscription(term)
          grant_credit(-cents) if cents.negative?
          Outcome.new(cents.negative? ? :credited : :no_charge, cents.abs, credit)
        end

        def grant_credit(cents)
          Credit::Grant.call(platform: term.platform, holder: term.payer, amount_cents: cents, currency: term.currency, origin: 'adjustment',
                             idempotency_key: "plan_change:#{term.id}:#{term.pay_subscription.current_period_end.to_i}:#{term.plan_id}",
                             note: I18n.t('better_together.billing.subscriptions.plan_change_credit_note'))
        end

        # A dearer plan: the difference is invoiced, and the plan changes when it is paid.
        def invoice(plan, cents)
          order = Orders::Place.call(**invoice_attributes(plan, cents))
          term.update!(pending_plan: plan, pending_plan_requested_at: Time.current, pending_plan_order: order)
          Outcome.new(:invoiced, cents, order)
        end

        def invoice_attributes(plan, cents)
          { **invoice_parties, purpose: 'subscription', renewal: true, payment_method: method_to_open,
                               line_items: [{ purchasable: plan, quantity: 1, unit_amount_cents: cents }],
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
