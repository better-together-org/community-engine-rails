# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EventReminderScanJob do
  include ActiveJob::TestHelper

  subject(:job) { described_class.new }

  describe 'queue configuration' do
    it 'uses the notifications queue' do
      expect(described_class.queue_name).to eq('notifications')
    end
  end

  describe '#perform' do
    before { configure_host_platform }

    let(:upcoming_event) { create('better_together/event', :upcoming) }

    it 'enqueues EventReminderSchedulerJob for each upcoming event' do
      upcoming_event
      expect do
        job.perform(window_hours: 200)
      end.to have_enqueued_job(BetterTogether::EventReminderSchedulerJob)
        .with(upcoming_event.id)
    end

    it 'does not enqueue jobs for events outside the scan window' do
      far_future = create('better_together/event',
                          starts_at: 300.hours.from_now,
                          ends_at: 301.hours.from_now)
      expect do
        job.perform(window_hours: 48)
      end.not_to have_enqueued_job(BetterTogether::EventReminderSchedulerJob)
         .with(far_future.id)
    end

    it 'scopes to a platform_id when provided' do
      platform_a = create(:better_together_platform, :public)
      platform_b = create(:better_together_platform, :public)
      event_a = create('better_together/event', :upcoming, platform: platform_a)
      event_b = create('better_together/event', :upcoming, platform: platform_b)

      job.perform(window_hours: 200, platform_id: platform_a.id)

      expect(enqueued_jobs.map { |j| j[:args] }).to include([event_a.id])
      expect(enqueued_jobs.map { |j| j[:args] }).not_to include([event_b.id])
    end
  end
end
