# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # Whether a subscription may move to a plan, and why not (see ChangePlan).
      class PlanChangeCheck
        # The prices the subscription could move to, this plan's own other intervals first.
        def self.options(term)
          check = new(term)
          candidates(term).includes(:product).select { |price| check.refusal(price).nil? }
                          .sort_by { |price| [price.product_id == term.plan_id ? 0 : 1, price.amount_cents] }
        end

        def self.candidates(term)
          recurring = Price.active.where(kind: 'recurring')
          recurring.where(product_id: term.platform.billing_plans.sold_by_platform.active.listed.select(:id))
                   .or(recurring.where(product_id: term.plan_id)).where.not(id: term.price_id)
        end

        def initialize(term)
          @term = term
        end

        # Why a move to this price is not possible, or nil. A move now must keep the interval; from the next period it need not.
        def refusal(price, now: false)
          return :not_running unless running?
          return :same_price if price.id == term.price_id
          return :not_available unless offered?(price)
          return :different_schedule unless same_schedule?(price, now:)

          :over_limit if price.product_id != term.plan_id && over_limit?(price.product)
        end

        private

        attr_reader :term

        def running?
          term.local? && term.pay_subscription.status == 'active' && term.pay_subscription.ends_at.blank?
        end

        def offered?(price)
          plan = price.product
          plan.is_a?(Plan) && plan_offered?(plan) && price.recurring? && price.active? && !price.archived? && !price.free?
        end

        def plan_offered?(plan)
          plan.platform_id == term.platform_id && plan.seller_id.blank? && plan.active? && (plan.listed? || plan.id == term.plan_id)
        end

        def same_schedule?(price, now:)
          return false unless price.currency == term.currency

          !now || (price.interval == term.price.interval && price.interval_count == term.price.interval_count)
        end

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
          grants = plan.grants.where(kind: 'quota_allowance')
          grants.to_h { |grant| [grant.parameters['quota_type'].to_s, Integer(grant.parameters['amount'], exception: false).to_i] }
        end
      end
    end
  end
end
