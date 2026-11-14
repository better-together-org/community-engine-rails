# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::EnqueueStuckBillingEventsJob do
  include ActiveJob::TestHelper

  let!(:host_platform) { configure_host_platform }

  it 'uses the billing queue' do
    expect(described_class.new.queue_name).to eq('billing')
  end

  it 'enqueues a processing job, by event id only, for each stuck pending event' do
    stuck = create(:better_together_billing_event, processing_status: 'pending', created_at: 30.minutes.ago)
    fresh = create(:better_together_billing_event, processing_status: 'pending', created_at: 1.minute.ago)

    expect { described_class.perform_now }
      .to have_enqueued_job(BetterTogether::Billing::ProcessBillingEventJob).with(stuck.id).exactly(:once)
    expect(BetterTogether::Billing::ProcessBillingEventJob).not_to have_been_enqueued.with(fresh.id)
  end

  it 'does nothing when nothing is stuck' do
    create(:better_together_billing_event, processing_status: 'processed', created_at: 2.hours.ago)

    expect { described_class.perform_now }.not_to have_enqueued_job(BetterTogether::Billing::ProcessBillingEventJob)
  end

  it 'keeps going when one event cannot be enqueued' do
    first = create(:better_together_billing_event, processing_status: 'pending', created_at: 40.minutes.ago)
    second = create(:better_together_billing_event, processing_status: 'pending', created_at: 30.minutes.ago)
    allow(Rails.logger).to receive(:error)
    allow(BetterTogether::Billing::ProcessBillingEventJob).to receive(:perform_later).and_call_original
    allow(BetterTogether::Billing::ProcessBillingEventJob).to receive(:perform_later).with(first.id).and_raise(StandardError, 'queue down')

    described_class.perform_now

    expect(BetterTogether::Billing::ProcessBillingEventJob).to have_received(:perform_later).with(second.id)
    expect(Rails.logger).to have_received(:error).with(/could not re-enqueue event #{first.id}: StandardError/)
  end

  it 'does not decrypt payloads just to find the stuck events' do
    create(:better_together_billing_event, processing_status: 'pending', created_at: 30.minutes.ago)
    selects = []
    callback = ->(*, payload) { selects << payload[:sql] if payload[:sql].start_with?('SELECT') && payload[:sql].include?('billing_events') }

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { described_class.perform_now }

    expect(selects.first).to include('"id"')
    expect(selects.first).not_to include('"payload"')
  end
end
