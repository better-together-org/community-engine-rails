# frozen_string_literal: true

module BetterTogether
  module Billing
    module Plans
      # The primary plans a person holds on a platform right now, which decides whether they may buy an add-on of one on its own.
      #
      # A person holds a plan when it gives them a live entitlement, when they pay for a live subscription to it, or when they bought
      # it once and the order stands (paid, or part refunded). A plan with nothing included gives no entitlement, so the paid order
      # and the subscription are looked at directly. A refunded or cancelled order, and a lapsed subscription, hold nothing.
      class Holdings
        HELD_ORDERS = %w[paid partially_refunded].freeze

        def self.call(...) = new(...).call

        def initialize(platform:, person:)
          @platform = platform
          @person = person
        end

        # Ids of primary plans held (an add-on is never "held": it extends something else).
        def call
          return [] unless person && platform

          ids = [*entitled_plan_ids, *subscribed_plan_ids, *bought_plan_ids].uniq
          Plan.where(platform_id: platform.id, id: ids, add_on: false).pluck(:id)
        end

        private

        attr_reader :platform, :person

        def entitled_plan_ids = Entitlements::ForPerson.call(platform:, person:).live.pluck(:plan_id)

        def subscribed_plan_ids
          platform.billing_subscription_terms.joins(pay_subscription: :customer)
                  .where(pay_customers: { owner_type: BetterTogether::Person.name, owner_id: person.id })
                  .where(pay_subscriptions: { status: 'active' }).pluck(:plan_id)
        end

        def bought_plan_ids
          LineItem.joins(:order)
                  .where(better_together_billing_orders: { platform_id: platform.id, buyer_id: person.id, status: HELD_ORDERS })
                  .where(purchasable_type: Plan.name).pluck(:purchasable_id)
        end
      end
    end
  end
end
