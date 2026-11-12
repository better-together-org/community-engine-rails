# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # A payer moves a subscription Community Engine renews to another of the platform's plans. No money moves at the moment
      # of the request, so there is nothing to prorate: the change takes effect when the next period starts, the next invoice is
      # made for the new plan at its price, and what the plan includes is brought in line then (see `apply`). Until then
      # nothing changes, and the request can be withdrawn.
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

        def self.request(term:, plan:) = new(term:).request(plan)
        def self.withdraw(term:) = term.update!(pending_plan: nil, pending_plan_requested_at: nil)

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
          term.update!(plan:, unit_amount_cents: plan.amount_cents, currency: plan.currency, pending_plan: nil, pending_plan_requested_at: nil)
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

        # Why a move to this plan is not possible, or nil.
        def refusal(plan)
          return :not_running unless running?
          return :same_plan if plan.id == term.plan_id
          return :not_available unless offered?(plan)
          return :different_schedule unless same_schedule?(plan)

          :over_limit if over_limit?(plan)
        end

        private

        attr_reader :term

        def running?
          term.local? && term.pay_subscription.status == 'active' && term.pay_subscription.ends_at.blank?
        end

        def offered?(plan) = plan.platform_id == term.platform_id && plan.seller_id.blank? && plan.active? && !plan.free?

        def same_schedule?(plan)
          current = term.plan
          plan.billing_interval == current.billing_interval && plan.interval_count == current.interval_count && plan.currency == term.currency
        end

        # What the holder uses is more than the limit would be on the new plan.
        def over_limit?(plan)
          owner = term.beneficiary_or_payer
          now = allowances(term.plan)
          later = allowances(plan)
          now.keys.union(later.keys).any? { |type| exceeds?(Entitlements::Meter.for(owner:, type:), now[type].to_i, later[type].to_i) }
        end

        def exceeds?(reading, old_amount, new_amount)
          !reading.unlimited? && reading.used > reading.limit - old_amount + new_amount
        end

        def allowances(plan)
          grants = plan.plan_grants.where(kind: 'quota_allowance')
          grants.to_h { |grant| [grant.parameters['quota_type'].to_s, Integer(grant.parameters['amount'], exception: false).to_i] }
        end
      end
    end
  end
end
