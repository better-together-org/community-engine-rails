# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::EventProcessor do
  include_context 'with clean billing processors'

  before { BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new }) }

  def event_with(outcome)
    create(:better_together_billing_event, payload: { 'id' => 'evt_x', 'type' => 'fake.invoice.paid', 'outcome' => outcome })
  end

  %w[processed ignored alerted].each do |status|
    it "records a #{status} outcome without stamping errors" do
      event = event_with(status)

      described_class.call(event)

      expect(event.reload).to have_attributes(processing_status: status, attempt_count: 1, error_message: nil)
      expect(event.processed_at).to be_present
      expect(event.last_attempted_at).to be_present
    end
  end

  it 'keeps the event pending and raises a retryable error when a prerequisite is missing' do
    event = event_with('retry')

    expect { described_class.call(event) }.to raise_error(described_class::RetryableError, 'prerequisite_missing')

    expect(event.reload).to have_attributes(processing_status: 'pending', attempt_count: 1, error_message: 'prerequisite_missing',
                                            processed_at: nil)
  end

  it 'marks failures, stores a bounded message, does not stamp processed_at, and re-raises' do
    event = event_with('boom')

    expect { described_class.call(event) }.to raise_error(RuntimeError, 'fake processor failure')

    expect(event.reload).to have_attributes(processing_status: 'failed', error_message: 'fake processor failure', processed_at: nil)
  end

  it 'counts each attempt' do
    event = event_with('boom')

    2.times { expect { described_class.call(event) }.to raise_error(RuntimeError) }

    expect(event.reload.attempt_count).to eq(2)
  end

  it 'fails loudly when the processor adapter is not installed' do
    event = create(:better_together_billing_event, processor: 'gone')

    expect { described_class.call(event) }.to raise_error(described_class::MissingAdapterError, /gone/)
  end

  it 'rejects an adapter that does not return an EventResult' do
    adapter = BetterTogether::Billing::FakeAdapter.new
    allow(adapter).to receive(:process_event).and_return(:ok)
    BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)
    BetterTogether::Billing.register_processor(:fake, -> { adapter })

    expect { described_class.call(event_with('processed')) }.to raise_error(TypeError, /EventResult/)
  end

  it 'logs, and still raises the original error, when the failure cannot be recorded' do
    event = event_with('boom')
    allow(event).to receive(:update!).and_wrap_original do |original, **attrs|
      attrs[:processing_status] == 'failed' ? raise(ActiveRecord::StatementInvalid, 'db down') : original.call(**attrs)
    end
    allow(Rails.logger).to receive(:error)

    expect { described_class.call(event) }.to raise_error(RuntimeError, 'fake processor failure')
    expect(Rails.logger).to have_received(:error).with(/could not record failure/)
  end
end
