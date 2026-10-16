# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::WebhookDispatcher do
  include ActiveJob::TestHelper

  include_context 'with clean billing processors'

  let(:vendor_event) { { 'id' => 'evt_77', 'type' => 'fake.invoice.paid', 'customer_email' => 'person@example.test' } }

  before { BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new }) }

  it 'logs the event once and enqueues processing by id, never by payload' do
    expect { described_class.new(:fake).call(vendor_event) }.to have_enqueued_job(BetterTogether::Billing::ProcessBillingEventJob)

    event = BetterTogether::Billing::Event.find_by!(processor: 'fake', event_id: 'evt_77')
    expect(enqueued_jobs.last[:args]).to eq([event.id])
    expect(enqueued_jobs.last.to_s).not_to include('person@example.test')
  end

  it 'does not enqueue a second run for a duplicate delivery' do
    described_class.new(:fake).call(vendor_event)

    expect { described_class.new(:fake).call(vendor_event) }.not_to have_enqueued_job(BetterTogether::Billing::ProcessBillingEventJob)
    expect(BetterTogether::Billing::Event.where(event_id: 'evt_77').count).to eq(1)
  end

  it 'ignores events for a processor that is not installed' do
    BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)

    expect { described_class.new(:fake).call(vendor_event) }.not_to change(BetterTogether::Billing::Event, :count)
  end
end
