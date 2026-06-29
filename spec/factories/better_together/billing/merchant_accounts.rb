# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/merchant_account',
          class: 'BetterTogether::Billing::MerchantAccount',
          aliases: %i[better_together_billing_merchant_account] do
    association :owner, factory: :better_together_community
    provider { 'stripe_connect' }
    external_account_id { "acct_#{SecureRandom.hex(8)}" }
    status { 'pending' }
    charges_enabled { false }
    payouts_enabled { false }
    capabilities { {} }
    country { 'CA' }
    currency { 'CAD' }
    metadata { {} }

    trait :person_owned do
      association :owner, factory: :better_together_person
    end

    trait :active do
      status { 'active' }
      charges_enabled { true }
      payouts_enabled { true }
    end

    trait :paypal do
      provider { 'paypal_multiparty' }
      external_account_id { "paypal_#{SecureRandom.hex(8)}" }
    end
  end
end
