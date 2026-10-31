# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/order', class: 'BetterTogether::Billing::Order', aliases: %i[better_together_billing_order] do
    # Billing never guesses a platform, so an order is given one explicitly.
    platform { BetterTogether::Platform.find_by(host: true) || association(:better_together_platform, :host) }
    buyer { association :better_together_person }
    purpose { 'one_time' }
    status { 'draft' }
    currency { 'USD' }

    # An order with one line, waiting to be paid.
    trait :with_line do
      after(:build) do |order|
        order.lines.build(platform_id: order.platform_id, purchasable: order.platform.billing_plans.first || raise('create a plan first'),
                          description: 'Hosted', quantity: 1, unit_amount_cents: 4500, currency: order.currency)
      end
    end

    trait :awaiting_payment do
      status { 'awaiting_payment' }
      placed_at { Time.current }
      expires_at { 72.hours.from_now }
    end
  end

  factory 'better_together/billing/order_line', class: 'BetterTogether::Billing::OrderLine', aliases: %i[better_together_billing_order_line] do
    order { association :better_together_billing_order }
    platform_id { order.platform_id }
    purchasable { association :better_together_billing_plan, platform: order.platform }
    description { 'Hosted community' }
    quantity { 1 }
    unit_amount_cents { 4500 }
    currency { order.currency }
  end

  factory 'better_together/billing/payment', class: 'BetterTogether::Billing::Payment', aliases: %i[better_together_billing_payment] do
    order { association :better_together_billing_order, :awaiting_payment, total_cents: 4500 }
    platform_id { order.platform_id }
    processor { 'fake' }
    status { 'pending' }
    amount_cents { 4500 }
    currency { order.currency }
    idempotency_key { "pay-#{SecureRandom.hex(8)}" }
  end

  factory 'better_together/billing/refund', class: 'BetterTogether::Billing::Refund', aliases: %i[better_together_billing_refund] do
    payment { association :better_together_billing_payment, status: 'succeeded' }
    platform_id { payment.platform_id }
    amount_cents { 1000 }
    currency { payment.currency }
    status { 'recorded' }
    idempotency_key { "refund-#{SecureRandom.hex(8)}" }
  end
end

FactoryBot.define do
  factory 'better_together/billing/agreement_requirement', class: 'BetterTogether::Billing::AgreementRequirement',
                                                           aliases: %i[better_together_billing_agreement_requirement] do
    platform { BetterTogether::Platform.find_by(host: true) || association(:better_together_platform, :host) }
    agreement do
      association :better_together_agreement, agreement_kind: 'transactional_agreement', platform:,
                                              identifier: "purchase-#{SecureRandom.hex(4)}"
    end
    mode { 'additional' }
  end
end
