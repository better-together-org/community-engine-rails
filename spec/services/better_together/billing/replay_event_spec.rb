# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ReplayEvent do
  include ActiveJob::TestHelper

  include_context 'with clean billing processors'

  let(:requester) { create(:better_together_person) }
  let(:event) do
    create(:better_together_billing_event, processing_status: 'dead_lettered', dead_lettered_at: 1.hour.ago,
                                           dead_letter_reason: 'retries_exhausted')
  end

  before { BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new }) }

  it 'resets the event, counts the replay and enqueues by event id only' do
    result = nil
    expect { result = described_class.call(billing_event: event, requested_by: requester) }
      .to have_enqueued_job(BetterTogether::Billing::ProcessBillingEventJob).with(event.id)

    expect(result).to have_attributes(enqueued: true, reason: :enqueued)
    expect(event.reload).to have_attributes(processing_status: 'replayed', replay_count: 1, dead_letter_reason: nil,
                                            last_replay_requested_by_id: requester.id)
  end

  it 'refuses events that are not dead-lettered' do
    live = create(:better_together_billing_event)

    expect(described_class.call(billing_event: live, requested_by: requester)).to have_attributes(enqueued: false, reason: :not_dead_lettered)
  end

  it 'refuses events whose payload was redacted' do
    event.update!(payload_redacted_at: Time.current)

    expect(described_class.call(billing_event: event, requested_by: requester)).to have_attributes(enqueued: false, reason: :payload_unavailable)
  end

  it 'refuses events for a processor that is no longer installed' do
    BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)

    expect(described_class.call(billing_event: event,
                                requested_by: requester)).to have_attributes(enqueued: false,
                                                                             reason: :unsupported_processor)
  end
end
