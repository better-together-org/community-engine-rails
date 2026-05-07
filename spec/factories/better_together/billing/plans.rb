# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/plan',
          class: 'BetterTogether::Billing::Plan',
          aliases: %i[better_together_billing_plan] do
    identifier { "plan-#{SecureRandom.hex(6)}" }
    name { "Plan #{SecureRandom.hex(3)}" }
    description { 'Managed community subscription plan' }
    billing_interval { 'month' }
    amount_cents { 45_000 }
    currency { 'CAD' }
    active { true }
    stripe_price_id { "price_#{SecureRandom.hex(8)}" }
    metadata { {} }
  end
end
