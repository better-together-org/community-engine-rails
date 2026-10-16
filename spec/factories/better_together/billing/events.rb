# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/event',
          class: 'BetterTogether::Billing::Event',
          aliases: %i[better_together_billing_event] do
    processor { 'fake' }
    event_type { 'fake.invoice.paid' }
    event_id { "evt_#{SecureRandom.hex(8)}" }
    payload { { 'id' => event_id, 'type' => event_type } }
    processing_status { 'pending' }
  end
end
