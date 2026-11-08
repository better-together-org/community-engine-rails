# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::EventProcessor do
  include_context 'with clean billing processors'

  let!(:host_platform) { configure_host_platform }
  let(:adapter) { BetterTogether::Billing::FakeAdapter.new }

  before { BetterTogether::Billing.register_processor(:fake, -> { adapter }) }

  def event_with(outcome, **attrs)
    create(:better_together_billing_event, payload: { 'id' => 'evt_x', 'type' => 'fake.invoice.paid', 'outcome' => outcome }, **attrs)
  end

  %w[processed ignored alerted].each do |status|
    it "records a #{status} outcome without stamping errors" do
      event = event_with(status)

      described_class.call(event)

      expect(event.reload).to have_attributes(processing_status: status, attempt_count: 1, error_message: nil, claimed_at: nil)
      expect(event.processed_at).to be_present
      expect(event.last_attempted_at).to be_present
    end
  end

  describe 'what the outcome says happened' do
    it 'keeps the processor-neutral outcome kind on the event' do
      event = create(:better_together_billing_event,
                     payload: { 'id' => 'evt_k', 'type' => 'fake.invoice.payment_failed', 'outcome' => 'alerted',
                                'outcome_kind' => 'payment_failed' })

      described_class.call(event)

      expect(event.reload).to have_attributes(processing_status: 'alerted', outcome_kind: 'payment_failed')
    end

    it 'keeps the subject the adapter reports' do
      subject_platform = create(:better_together_platform)
      result = BetterTogether::Billing::EventResult.new(status: :processed, outcome_kind: :payment_succeeded, subject: subject_platform)
      allow(adapter).to receive(:process_event).and_return(result)
      event = event_with('processed')

      described_class.call(event)

      expect(event.reload).to have_attributes(subject: subject_platform, outcome_kind: 'payment_succeeded')
    end

    it 'leaves the outcome kind empty when the adapter reports none' do
      event = event_with('processed')

      described_class.call(event)

      expect(event.reload.outcome_kind).to be_nil
    end
  end

  it 'gives the adapter the platform context of the event, not an ambient one' do
    event = event_with('processed')
    Current.platform = create(:better_together_platform)

    described_class.call(event)

    _name, _id, context = adapter.calls.last
    expect(context).to have_attributes(platform: host_platform, processor: :fake)
  ensure
    Current.platform = nil
  end

  it 'keeps the event pending and raises a retryable error when a prerequisite is missing' do
    event = event_with('retry')

    expect { described_class.call(event) }.to raise_error(described_class::RetryableError, 'prerequisite_missing')

    expect(event.reload).to have_attributes(processing_status: 'pending', attempt_count: 1, error_message: 'prerequisite_missing',
                                            processed_at: nil, claimed_at: nil)
  end

  it 'marks failures, stores a bounded message, does not stamp processed_at, releases the claim, and re-raises' do
    event = event_with('boom')

    expect { described_class.call(event) }.to raise_error(RuntimeError, 'fake processor failure')

    expect(event.reload).to have_attributes(processing_status: 'failed', error_message: 'fake processor failure', processed_at: nil,
                                            claimed_at: nil)
  end

  it 'counts each attempt' do
    event = event_with('boom')

    2.times { expect { described_class.call(event) }.to raise_error(RuntimeError) }

    expect(event.reload.attempt_count).to eq(2)
  end

  it 'records a failure and raises when the processor adapter is not installed' do
    event = create(:better_together_billing_event, processor: 'gone')

    expect { described_class.call(event) }.to raise_error(described_class::MissingAdapterError, /gone/)
    expect(event.reload).to have_attributes(processing_status: 'failed', error_message: /no billing processor registered/)
  end

  it 'records a failure and raises when the event platform has no billing configuration for the processor' do
    event = event_with('processed', platform: create(:better_together_platform))

    expect { described_class.call(event) }.to raise_error(described_class::MissingContextError)
    expect(event.reload).to have_attributes(processing_status: 'failed', attempt_count: 0)
    expect(adapter.calls).to be_empty
  end

  it 'rejects an adapter that does not return an EventResult' do
    allow(adapter).to receive(:process_event).and_return(:ok)

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

  describe 'running more than once for the same event' do
    it 'does nothing for an event whose outcome is already final' do
      event = event_with('processed', processing_status: 'processed', processed_at: 1.hour.ago, attempt_count: 1)

      expect(described_class.call(event)).to be_nil
      expect(adapter.calls).to be_empty
      expect(event.reload.attempt_count).to eq(1)
    end

    it 'does not run the adapter while another job holds the event' do
      event = event_with('processed', claimed_at: 1.minute.ago)

      expect(described_class.call(event)).to be_nil
      expect(adapter.calls).to be_empty
    end

    it 'takes over an event whose claim has expired, as after a crashed worker' do
      event = event_with('processed', claimed_at: 1.hour.ago)

      described_class.call(event)

      expect(event.reload.processing_status).to eq('processed')
    end

    it 'runs the adapter once when two jobs start together' do
      event = event_with('processed')
      second_copy = BetterTogether::Billing::Event.find(event.id)

      described_class.call(event)
      described_class.call(second_copy)

      expect(adapter.calls.count { |name, *| name == :process_event }).to eq(1)
    end

    it 'records the outcome even though a sweep or replay changed the row while the adapter ran' do
      event = event_with('processed')
      allow(adapter).to receive(:process_event).and_wrap_original do |original, **kwargs|
        BetterTogether::Billing::Event.find(event.id).update!(last_replayed_at: Time.current)
        original.call(**kwargs)
      end

      expect { described_class.call(event) }.not_to raise_error
      expect(event.reload.processing_status).to eq('processed')
    end

    it 'clears the dead-letter state when a late success follows the sweep' do
      event = event_with('processed', processing_status: 'dead_lettered', dead_lettered_at: 1.hour.ago,
                                      dead_letter_reason: 'stale_unresolved_drift')

      described_class.call(event)

      expect(event.reload).to have_attributes(processing_status: 'processed', dead_lettered_at: nil, dead_letter_reason: nil)
    end
  end

  describe 'recording an outcome that cannot be saved' do
    it 'records a failure instead of leaving the event silently pending' do
      BetterTogether::Billing::Billable.model_names.delete('BetterTogether::Community')
      community = create(:better_together_community)
      allow(adapter).to receive(:process_event).and_return(
        BetterTogether::Billing::EventResult.new(status: :processed, billable_owner: community)
      )
      event = event_with('processed')

      expect { described_class.call(event) }.to raise_error(ActiveRecord::RecordInvalid)

      expect(event.reload).to have_attributes(processing_status: 'failed', claimed_at: nil)
      expect(event.error_message).to include('Billable owner type')
    end
  end
end
