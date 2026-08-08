# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/monetary_contribution',
          class: 'BetterTogether::Billing::MonetaryContribution',
          aliases: %i[better_together_billing_monetary_contribution] do
    association :sponsorship, factory: 'better_together/billing/sponsorship'
    amount_cents { 2_500 }
    currency { 'cad' }
    sequence(:stripe_balance_transaction_id) { |n| "txn_test_#{n}" }
  end
end
