# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ProcessBillingEventJob do
  include ActiveJob::TestHelper

  include_context 'with clean billing processors'

  before { BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new }) }

  it 'processes the event looked up by id' do
    event = create(:better_together_billing_event, payload: { 'id' => 'e', 'type' => 't', 'outcome' => 'processed' })

    described_class.perform_now(event.id)

    expect(event.reload.processing_status).to eq('processed')
  end

  it 'discards a job whose event no longer exists' do
    expect { described_class.perform_now(SecureRandom.uuid) }.not_to raise_error
  end

  it 'retries a missing-prerequisite result' do
    event = create(:better_together_billing_event, payload: { 'id' => 'e', 'type' => 't', 'outcome' => 'retry' })

    expect { described_class.perform_now(event.id) }.to have_enqueued_job(described_class).with(event.id)
  end

  it 'retries failures and takes only the event id' do
    event = create(:better_together_billing_event, payload: { 'id' => 'e', 'type' => 't', 'outcome' => 'boom' })

    expect { described_class.perform_now(event.id) }.to have_enqueued_job(described_class).with(event.id)
    expect(event.reload.processing_status).to eq('failed')
  end

  it 'uses the default queue' do
    expect(described_class.new.queue_name).to eq('default')
  end
end
