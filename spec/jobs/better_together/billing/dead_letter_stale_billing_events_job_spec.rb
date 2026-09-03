# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::DeadLetterStaleBillingEventsJob do
  describe '#perform' do
    it 'dead-letters stale unresolved events' do
      billing_event = create(
        :better_together_billing_event,
        processing_status: 'ignored',
        attempt_count: 1,
        last_attempted_at: 8.hours.ago
      )

      described_class.perform_now

      expect(billing_event.reload).to be_dead_lettered
      expect(billing_event.dead_letter_reason).to eq('stale_unresolved_drift')
      expect(billing_event.dead_lettered_at).to be_present
    end
  end
end
