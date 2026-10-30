# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::DeadLetterStaleBillingEventsJob do
  it 'uses the maintenance queue' do
    expect(described_class.new.queue_name).to eq('maintenance')
  end

  it 'dead-letters exhausted and stale events with the right reason and leaves healthy ones' do
    exhausted = create(:better_together_billing_event, processing_status: 'failed', attempt_count: 5, last_attempted_at: 1.minute.ago)
    stale = create(:better_together_billing_event, processing_status: 'pending', last_attempted_at: 8.hours.ago)
    healthy = create(:better_together_billing_event, processing_status: 'failed', attempt_count: 1, last_attempted_at: 1.minute.ago)
    done = create(:better_together_billing_event, processing_status: 'processed', attempt_count: 9, last_attempted_at: 9.hours.ago)

    described_class.perform_now

    expect(exhausted.reload).to have_attributes(processing_status: 'dead_lettered', dead_letter_reason: 'retries_exhausted')
    expect(stale.reload).to have_attributes(processing_status: 'dead_lettered', dead_letter_reason: 'stale_unresolved_drift')
    expect(healthy.reload.processing_status).to eq('failed')
    expect(done.reload.processing_status).to eq('processed')
  end
end
