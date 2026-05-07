# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/subscription',
          class: 'BetterTogether::Billing::Subscription',
          aliases: %i[better_together_billing_subscription] do
    association :billable_owner, factory: :better_together_community
    association :beneficiary, factory: :better_together_community
    association :billing_plan, factory: 'better_together/billing/plan'
    processor { 'stripe' }
    processor_subscription_id { "sub_#{SecureRandom.hex(8)}" }
    pay_customer_id { "cus_#{SecureRandom.hex(8)}" }
    status { 'active' }
    current_period_start { Time.current.beginning_of_day }
    current_period_end { 1.month.from_now.beginning_of_day }
    cancel_at_period_end { false }
    metadata { {} }

    trait :person_owned do
      association :billable_owner, factory: :better_together_person
      association :beneficiary, factory: :better_together_person
    end
  end
end
