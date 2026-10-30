# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/billing/event',
          class: 'BetterTogether::Billing::Event',
          aliases: %i[better_together_billing_event] do
    # Billing never guesses a platform, so an event is given one explicitly. The host
    # platform is the only one with a processor context today.
    platform { BetterTogether::Platform.find_by(host: true) || association(:better_together_platform, :host) }
    processor { 'fake' }
    event_type { 'fake.invoice.paid' }
    event_id { "evt_#{SecureRandom.hex(8)}" }
    payload { { 'id' => event_id, 'type' => event_type } }
    processing_status { 'pending' }
  end
end
