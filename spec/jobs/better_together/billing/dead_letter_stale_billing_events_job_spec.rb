# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::DeadLetterStaleBillingEventsJob do
  let!(:host_platform) { configure_host_platform }

  it 'uses the billing queue' do
    expect(described_class.new.queue_name).to eq('billing')
  end

  it 'dead-letters exhausted and stale events with the right reason and leaves healthy ones' do
    exhausted = create(:better_together_billing_event, processing_status: 'failed', attempt_count: 5, last_attempted_at: 1.minute.ago)
    stale = create(:better_together_billing_event, processing_status: 'pending', last_attempted_at: 8.hours.ago)
    healthy = create(:better_together_billing_event, processing_status: 'failed', attempt_count: 1, last_attempted_at: 1.minute.ago)
    done = create(:better_together_billing_event, processing_status: 'processed', attempt_count: 9, last_attempted_at: 9.hours.ago)

    described_class.perform_now

    expect(exhausted.reload).to have_attributes(processing_status: 'dead_lettered', dead_letter_reason: 'retries_exhausted')
    expect(stale.reload).to have_attributes(processing_status: 'dead_lettered', dead_letter_reason: 'stale_unresolved_drift')
    expect(healthy.reload.processing_status).to eq('failed')
    expect(done.reload.processing_status).to eq('processed')
  end

  it 'leaves an event alone that a job finished after the sweep selected it' do
    event = create(:better_together_billing_event, processing_status: 'failed', attempt_count: 5, last_attempted_at: 1.minute.ago)
    allow(BetterTogether::Billing::Event).to receive(:find).and_wrap_original do |original, id|
      BetterTogether::Billing::Event.where(id:).update_all(processing_status: 'processed') # a job finishing mid-sweep
      original.call(id)
    end

    described_class.perform_now

    expect(event.reload.processing_status).to eq('processed')
  end

  it 'does not decrypt payloads just to find the stuck events' do
    create(:better_together_billing_event, processing_status: 'failed', attempt_count: 5, last_attempted_at: 1.minute.ago)
    selects = []
    callback = lambda do |*, payload|
      sql = payload[:sql]
      selects << sql if sql.start_with?('SELECT') && sql.include?('FROM "better_together_billing_events"')
    end

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { described_class.perform_now }

    expect(selects.first).to include('"better_together_billing_events"."id"')
    expect(selects.first).not_to include('"payload"')
  end

  it 'keeps going when one event cannot be dead-lettered' do
    bad = create(:better_together_billing_event, processing_status: 'failed', attempt_count: 5, last_attempted_at: 1.minute.ago)
    good = create(:better_together_billing_event, processing_status: 'failed', attempt_count: 5, last_attempted_at: 1.minute.ago)
    allow(BetterTogether::Billing::Event).to receive(:find).and_wrap_original do |original, id|
      record = original.call(id)
      allow(record).to receive(:dead_letter_if_stale!).and_raise(ActiveRecord::StaleObjectError.new(record, 'update')) if id == bad.id
      record
    end
    allow(Rails.logger).to receive(:error)

    expect { described_class.perform_now }.not_to raise_error

    expect(good.reload.processing_status).to eq('dead_lettered')
    expect(bad.reload.processing_status).to eq('failed')
    expect(Rails.logger).to have_received(:error).with(/could not dead-letter event #{bad.id}/)
  end
end
