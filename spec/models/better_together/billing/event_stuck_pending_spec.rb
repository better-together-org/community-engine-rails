# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Event, '.stuck_pending' do
  let!(:host_platform) { configure_host_platform }

  def pending_event(**attrs) = create(:better_together_billing_event, processing_status: 'pending', **attrs)

  it 'finds a pending event that never got a job for longer than the grace period' do
    stuck = pending_event(created_at: 30.minutes.ago)
    pending_event(created_at: 1.minute.ago)

    expect(described_class.stuck_pending).to contain_exactly(stuck)
  end

  it 'leaves a retrying event alone until its longest wait is over' do
    waiting = pending_event(attempt_count: 2, last_attempted_at: 20.minutes.ago)
    forgotten = pending_event(attempt_count: 2, last_attempted_at: 50.minutes.ago)

    expect(described_class.stuck_pending).to contain_exactly(forgotten)
    expect(described_class.stuck_pending).not_to include(waiting)
  end

  it 'leaves out an event a job holds, one the dead-letter sweep takes, and every other state' do
    pending_event(created_at: 1.hour.ago, claimed_at: 1.minute.ago)
    pending_event(created_at: 8.hours.ago)
    create(:better_together_billing_event, processing_status: 'failed', created_at: 1.hour.ago)
    create(:better_together_billing_event, processing_status: 'processed', created_at: 1.hour.ago)

    expect(described_class.stuck_pending).to be_empty
  end

  it 'takes an event whose lease belonged to a crashed worker' do
    crashed = pending_event(created_at: 1.hour.ago, claimed_at: 30.minutes.ago)

    expect(described_class.stuck_pending).to contain_exactly(crashed)
  end
end
