# frozen_string_literal: true

module BetterTogether
  module Billing
    module Entitlements
      # What a person has because of a plan on a platform: what is for them, and what they pay for (for someone else).
      class ForPerson
        def self.call(...) = new(...).call

        def initialize(platform:, person:)
          @platform = platform
          @person = person
        end

        def call
          all = platform.billing_entitlements
          all.where(beneficiary: person).or(all.where(pay_subscription_id: paid_subscription_ids))
             .or(all.where(order_id: paid_order_ids))
        end

        private

        attr_reader :platform, :person

        def paid_subscription_ids
          platform.billing_subscription_terms.joins(pay_subscription: :customer)
                  .where(pay_customers: { owner_type: BetterTogether::Person.name, owner_id: person.id }).select(:pay_subscription_id)
        end

        def paid_order_ids = platform.billing_orders.bought_by(person).select(:id)
      end
    end
  end
end
