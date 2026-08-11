# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/sponsorship',
          class: 'BetterTogether::Billing::Sponsorship',
          aliases: %i[better_together_billing_sponsorship] do
    association :sponsor, factory: :better_together_person
    association :beneficiary, factory: :better_together_community
    status { 'active' }
  end
end
