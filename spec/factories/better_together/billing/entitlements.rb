# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/entitlement',
          class: 'BetterTogether::Billing::Entitlement',
          aliases: %i[better_together_billing_entitlement] do
    association :holder, factory: :better_together_community
    entitlement_key { 'hosted_access' }
    status { 'active' }
    granted_at { Time.current }
  end
end
