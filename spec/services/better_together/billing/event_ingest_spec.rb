# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::EventIngest do
  let!(:platform) { configure_host_platform }
  let(:args) do
    { processor: :fake, platform:, event_id: 'evt_1', event_type: 'fake.invoice.paid',
      payload: { 'id' => 'evt_1', 'type' => 'fake.invoice.paid' } }
  end

  it 'logs a new event as pending for its platform and reports it created' do
    ingested = described_class.call(**args)

    expect(ingested.created).to be true
    expect(ingested.event).to have_attributes(processor: 'fake', event_id: 'evt_1', processing_status: 'pending',
                                              attempt_count: 0, platform:)
    expect(ingested.event.first_received_at).to be_present
  end

  it 'keeps the processor time of the event when the adapter supplies one' do
    occurred = Time.zone.parse('2026-10-01 12:00:00')

    expect(described_class.call(**args, occurred_at: occurred).event.processor_event_created_at).to eq(occurred)
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

  it 'refuses to hand one platform an event that is already logged for another' do
    described_class.call(**args)
    other = create(:better_together_platform)

    expect { described_class.call(**args, platform: other) }.to raise_error(described_class::PlatformConflictError)
    expect(BetterTogether::Billing::Event.where(event_id: 'evt_1').pluck(:platform_id)).to eq([platform.id])
  end

  it 'encrypts what it stores' do
    event = described_class.call(**args, payload: { 'id' => 'evt_1', 'type' => 't', 'customer_email' => 'private.person@example.test' }).event

    expect(event.ciphertext_for(:payload)).not_to include('private.person')
  end
end
