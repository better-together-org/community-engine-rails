# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::EventIngest do
  let(:args) do
    { processor: :fake, event_id: 'evt_1', event_type: 'fake.invoice.paid', payload: { 'id' => 'evt_1', 'type' => 'fake.invoice.paid' } }
  end

  it 'logs a new event as pending and reports it created' do
    ingested = described_class.call(**args)

    expect(ingested.created).to be true
    expect(ingested.event).to have_attributes(processor: 'fake', event_id: 'evt_1', processing_status: 'pending', attempt_count: 0)
    expect(ingested.event.first_received_at).to be_present
  end

  it 'returns the existing row for a duplicate delivery' do
    first = described_class.call(**args)
    second = described_class.call(**args, payload: { 'id' => 'evt_1', 'type' => 'changed' })

    expect(second.created).to be false
    expect(second.event).to eq(first.event)
    expect(first.event.reload.payload['type']).to eq('fake.invoice.paid')
  end

  it 'treats a concurrent insert as a duplicate' do
    existing = create(:better_together_billing_event, processor: 'fake', event_id: 'evt_1')
    lookups = [nil, existing]
    allow(BetterTogether::Billing::Event).to(receive(:find_by).and_wrap_original do |original, *a|
      lookups.empty? ? original.call(*a) : lookups.shift
    end)

    expect(described_class.call(**args)).to have_attributes(created: false, event: existing)
  end
end
