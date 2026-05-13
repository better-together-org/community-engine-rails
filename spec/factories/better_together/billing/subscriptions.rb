# frozen_string_literal: true

FactoryBot.define do
  # Pay::Customer factory — one customer record per payable owner per processor.
  factory 'pay/customer', class: 'Pay::Customer' do
    association :owner, factory: :better_together_community
    processor { 'stripe' }
    sequence(:processor_id) { |n| "cus_test_#{n}" }
    default { true }

    trait :person_owned do
      association :owner, factory: :better_together_person
      sequence(:processor_id) { |n| "cus_person_test_#{n}" }
    end
  end

  # Pay::Subscription factory — one subscription record per customer.
  factory 'pay/subscription', class: 'Pay::Subscription' do
    association :customer, factory: 'pay/customer'
    name { 'default' }
    sequence(:processor_id) { |n| "sub_test_#{n}" }
    processor_plan { 'price_test_default' }
    quantity { 1 }
    status { 'active' }
    current_period_start { Time.current.beginning_of_day }
    current_period_end { 1.month.from_now.beginning_of_day }

    trait :person_owned do
      association :customer, factory: %i[pay/customer person_owned]
      sequence(:processor_id) { |n| "sub_person_test_#{n}" }
    end
  end

  # BetterTogether::Billing::Subscription — thin CE extension of Pay::Subscription.
  factory 'better_together/billing/subscription',
          class: 'BetterTogether::Billing::Subscription',
          aliases: %i[better_together_billing_subscription] do
    association :pay_subscription, factory: 'pay/subscription'
    association :billing_plan, factory: 'better_together/billing/plan'
    metadata { {} }

    trait :person_owned do
      association :pay_subscription, factory: %i[pay/subscription person_owned]
    end
  end
end
