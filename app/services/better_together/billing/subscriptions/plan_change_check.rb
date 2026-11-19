# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # Whether a subscription may move to a plan, and why not (see ChangePlan).
      class PlanChangeCheck
        def initialize(term)
          @term = term
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
