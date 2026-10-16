# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::RedactExpiredEventPayloadsJob do
  include_context 'with clean billing processors'

  before { BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new }) }

  it 'uses the maintenance queue' do
    expect(described_class.new.queue_name).to eq('maintenance')
  end

  it 'redacts only payloads older than the retention window' do
    payload = { 'id' => 'evt', 'type' => 'fake.invoice.paid', 'customer_email' => 'secret@example.test' }
    expired = create(:better_together_billing_event, processed_at: 31.days.ago, payload:)
    recent = create(:better_together_billing_event, processed_at: 1.day.ago, payload:)

    described_class.perform_now

    expect(expired.reload.payload).to eq('id' => 'evt', 'type' => 'fake.invoice.paid')
    expect(expired.payload_redacted_at).to be_present
    expect(recent.reload.payload['customer_email']).to eq('secret@example.test')
  end

  it 'does nothing when another run holds the lock' do
    expired = create(:better_together_billing_event, processed_at: 31.days.ago, payload: { 'id' => 'e', 'type' => 't', 'x' => 1 })
    redis = instance_double(Redis, set: false)
    allow(Sidekiq).to receive(:redis).and_yield(redis)

    described_class.perform_now

    expect(expired.reload.payload_redacted_at).to be_nil
  end
end
