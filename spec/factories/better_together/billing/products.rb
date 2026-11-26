# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/product',
          class: 'BetterTogether::Billing::Product',
          aliases: %i[better_together_billing_product] do
    platform { BetterTogether::Platform.find_by(host: true) || association(:better_together_platform, :host) }
    identifier { "product-#{SecureRandom.hex(6)}" }
    name { 'Storage top-up' }
    description { 'Extra storage for your account.' }
    active { true }

    trait :fixed_term do
      lifetime { 'fixed_term' }
      term_length { 12 }
      term_unit { 'month' }
    end
  end
end
