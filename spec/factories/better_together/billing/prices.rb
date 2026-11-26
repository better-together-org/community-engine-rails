# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/price',
          class: 'BetterTogether::Billing::Price',
          aliases: %i[better_together_billing_price] do
    association :product, factory: :better_together_billing_product
    platform { product.platform }
    amount_cents { 500 }
    currency { 'CAD' }
  end
end
