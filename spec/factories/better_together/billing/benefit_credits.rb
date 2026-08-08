# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/benefit_credit',
          class: 'BetterTogether::Billing::BenefitCredit',
          aliases: %i[better_together_billing_benefit_credit] do
    association :beneficiary, factory: :better_together_community
    benefit_key { 'event_registration' }
    quantity { 1 }
  end
end
