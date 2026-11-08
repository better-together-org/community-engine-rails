# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/plan',
          class: 'BetterTogether::Billing::Plan',
          aliases: %i[better_together_billing_plan] do
    # Billing never guesses a platform, so a plan is given one explicitly. The host
    # platform is the only one with a processor context today.
    platform { BetterTogether::Platform.find_by(host: true) || association(:better_together_platform, :host) }
    identifier { "plan-#{SecureRandom.hex(6)}" }
    name { "Plan #{SecureRandom.hex(3)}" }
    description { 'Managed community subscription plan' }
    billing_interval { 'month' }
    amount_cents { 45_000 }
    currency { 'USD' }
    active { true }
    processor { 'fake' }
    # A linked plan by default: the price exists at the processor and has been synced.
    processor_price_id { "price_#{SecureRandom.hex(8)}" }
    processor_product_id { "prod_#{SecureRandom.hex(6)}" }
    sync_status { 'synced' }
    metadata do
      {
        'participant_summary' => 'Supports hosted participation and stewardship for this Better Together space.',
        'participant_benefits' => ['Hosted access', 'Ongoing stewardship support'],
        'beneficiary_label' => 'Hosted access',
        'hosted_access_level' => 'Standard',
        'support_tier' => 'Community'
      }
    end

    trait :one_time do
      billing_interval { 'one_time' }
    end

    # Created in Community Engine and waiting for the first push to the processor.
    trait :unlinked do
      processor_price_id { nil }
      processor_product_id { nil }
      sync_status { 'pending' }
    end

    # Factories skip the processor and price checks that guard steward creation.
    to_create { |plan| plan.save!(validate: false) }
  end
end
