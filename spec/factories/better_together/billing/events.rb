# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/event',
          class: 'BetterTogether::Billing::Event',
          aliases: %i[better_together_billing_event] do
    association :billable_owner, factory: :better_together_community
    association :beneficiary, factory: :better_together_community
    association :billing_subscription, factory: 'better_together/billing/subscription'
    processor { 'stripe' }
    event_type { 'customer.subscription.updated' }
    event_id { "evt_#{SecureRandom.hex(8)}" }
    payload { { 'id' => event_id, 'type' => event_type } }
    processing_status { 'pending' }
    error_message { nil }
  end
end
