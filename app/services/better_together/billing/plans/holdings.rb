# frozen_string_literal: true

module BetterTogether
  module Billing
    module Plans
      # The plans a person holds on a platform right now, which decides whether they may buy an extra that needs one.
      #
      # A person holds a plan when it gives them a live entitlement, or when they pay for a live subscription to it. A plan with
      # nothing included gives no entitlement, so the subscription is looked at directly. A lapsed subscription holds nothing.
      class Holdings
        def self.call(...) = new(...).call

        def initialize(platform:, person:)
          @platform = platform
          @person = person
        end

        # Ids of plans held.
        def call
          return [] unless person && platform

          ids = [*entitled_plan_ids, *subscribed_plan_ids].uniq
          Plan.where(platform_id: platform.id, id: ids).pluck(:id)
        end

        private

        attr_reader :platform, :person

        def entitled_plan_ids = Entitlements::ForPerson.call(platform:, person:).live.pluck(:plan_id)

        def subscribed_plan_ids
          platform.billing_subscription_terms.joins(pay_subscription: :customer)
                  .where(pay_customers: { owner_type: BetterTogether::Person.name, owner_id: person.id })
                  .where(pay_subscriptions: { status: 'active' }).pluck(:plan_id)
        end
      end
    end
  end
end
