# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ProcessBillingEventJob do
  include ActiveJob::TestHelper

  include_context 'with clean billing processors'

  let!(:host_platform) { configure_host_platform }

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

  it 'runs on the billing queue' do
    expect(described_class.new.queue_name).to eq('billing')
  end

  describe 'waiting for a prerequisite' do
    it 'backs off over about forty minutes instead of retrying every half minute' do
      waits = described_class::RETRY_WAITS

      expect(waits.first).to eq(30.seconds)
      expect(waits.sum).to be_between(30.minutes, 90.minutes)
      expect(waits).to eq(waits.sort)
    end

    it 'enqueues each retry later than the one before' do
      event = create(:better_together_billing_event, payload: { 'id' => 'e', 'type' => 't', 'outcome' => 'retry' })
      scheduled = []

      job = described_class.new(event.id)
      allow(job).to receive(:retry_job) { |options| scheduled << options[:wait] }
      allow(job).to receive(:executions).and_return(1, 2, 3)
      3.times do
        BetterTogether::Billing::Event.find(event.id).update!(claimed_at: nil, processing_status: 'pending')
        job.perform_now
      end

      expect(scheduled.size).to eq(3)
      expect(scheduled).to eq(scheduled.sort)
    end
  end
end
