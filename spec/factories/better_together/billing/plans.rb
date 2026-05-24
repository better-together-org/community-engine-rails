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
    metadata do
      {
        'participant_summary' => 'Supports hosted participation and stewardship for this Better Together space.',
        'participant_benefits' => ['Hosted access', 'Ongoing stewardship support'],
        'beneficiary_label' => 'Hosted access',
        'hosted_access_level' => 'Standard',
        'support_tier' => 'Community'
      }
    end
  end
end
