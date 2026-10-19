# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/one_time_payment',
          class: 'BetterTogether::Billing::OneTimePayment',
          aliases: %i[better_together_billing_one_time_payment] do
    association :owner, factory: :better_together_community
    association :billing_plan, factory: 'better_together/billing/plan', billing_interval: 'one_time'
    sequence(:stripe_checkout_session_id) { |n| "cs_test_one_time_payment_#{n}" }
    sequence(:stripe_payment_intent_id) { |n| "pi_test_#{n}" }
    amount_cents { 2_500 }
    currency { 'cad' }
    status { 'succeeded' }
  end
end
