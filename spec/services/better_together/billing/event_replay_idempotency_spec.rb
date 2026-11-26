# frozen_string_literal: true

require 'rails_helper'

# Replaying is safe to do twice: the second request is refused, and even a second job for the same
# event does not run the processor again.
RSpec.describe 'Billing event replay idempotency' do # rubocop:disable RSpec/DescribeClass
  include ActiveJob::TestHelper

  include_context 'with clean billing processors'

  let!(:host_platform) { configure_host_platform }
  let(:adapter) { BetterTogether::Billing::FakeAdapter.new }
  let(:operator) { create(:better_together_person) }
  let(:event) do
    create(:better_together_billing_event, processing_status: 'dead_lettered', dead_lettered_at: 1.hour.ago,
                                           dead_letter_reason: 'retries_exhausted', attempt_count: 5)
  end

  before { BetterTogether::Billing.register_processor(:fake, -> { adapter }) }

  def process_calls = adapter.calls.count { |call| call.first == :process_event }

  it 'applies the event once however many times it is replayed' do
    first = BetterTogether::Billing::ReplayEvent.call(billing_event: event, requested_by: operator)
    perform_enqueued_jobs
    second = BetterTogether::Billing::ReplayEvent.call(billing_event: event.reload, requested_by: operator)
    perform_enqueued_jobs

    expect(first.enqueued).to be(true)
    expect(second).to have_attributes(enqueued: false, reason: :not_replayable)
    expect(process_calls).to eq(1)
    expect(event.reload).to have_attributes(processing_status: 'processed', replay_count: 1)
  end

  it 'refuses the second replay when both are asked before the job runs' do
    BetterTogether::Billing::ReplayEvent.call(billing_event: event, requested_by: operator)
    again = BetterTogether::Billing::ReplayEvent.call(billing_event: event.reload, requested_by: operator)

    expect(again.enqueued).to be(false)
    expect(enqueued_jobs.count { |job| job['job_class'] == 'BetterTogether::Billing::ProcessBillingEventJob' }).to eq(1)
  end

  it 'does not run the processor again when a duplicate job arrives after the event went through' do
    BetterTogether::Billing::ReplayEvent.call(billing_event: event, requested_by: operator)
    2.times { BetterTogether::Billing::ProcessBillingEventJob.perform_now(event.id) }

    expect(process_calls).to eq(1)
  end

  it 'can retry a failed event too' do
    failed = create(:better_together_billing_event, processing_status: 'failed', attempt_count: 2)

    expect(BetterTogether::Billing::ReplayEvent.call(billing_event: failed, requested_by: operator)).to have_attributes(enqueued: true)
    expect(failed.reload.processing_status).to eq('replayed')
  end
end
