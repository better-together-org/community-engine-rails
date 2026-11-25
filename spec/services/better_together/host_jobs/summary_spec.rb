# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::HostJobs::Summary do
  let(:now) { Time.zone.parse('2026-11-17 12:00:00') }
  let(:queues) do
    [
      instance_double(Sidekiq::Queue, name: 'default', size: 3, latency: 12.5),
      instance_double(Sidekiq::Queue, name: 'mailers', size: 7, latency: 90.0)
    ]
  end
  let(:stats) do
    instance_double(Sidekiq::Stats, failed: 42, retry_size: 5, dead_size: 2, scheduled_size: 4)
  end
  let(:run_ats) { [now - 2.minutes, now - 15.minutes, now - 45.minutes] }
  let(:process_count) { 2 }

  before do
    allow(Sidekiq::Stats).to receive(:new).and_return(stats)
    allow(Sidekiq::Queue).to receive(:all).and_return(queues)
    work_set = run_ats.map { |run_at| ['proc', 'tid', instance_double(Sidekiq::Work, run_at:)] }
    allow(Sidekiq::WorkSet).to receive(:new).and_return(work_set)
    allow(Sidekiq::ProcessSet).to receive(:new).with(false).and_return(instance_double(Sidekiq::ProcessSet, size: process_count))
  end

  describe '#snapshot' do
    subject(:snapshot) { described_class.new(stalled_after: 10.minutes, now:).snapshot }

    it 'reports failed, retrying, dead and scheduled counts', :aggregate_failures do
      expect(snapshot).to be_available
      expect(snapshot.failed).to eq(42)
      expect(snapshot.retrying).to eq(5)
      expect(snapshot.dead).to eq(2)
      expect(snapshot.scheduled).to eq(4)
    end

    it 'lists queues largest first with the total and the longest latency', :aggregate_failures do
      expect(snapshot.queues.map(&:name)).to eq(%w[mailers default])
      expect(snapshot.enqueued).to eq(10)
      expect(snapshot.longest_latency).to eq(90.0)
    end

    it 'counts jobs running longer than the threshold as stalled', :aggregate_failures do
      expect(snapshot.busy).to eq(3)
      expect(snapshot.stalled).to eq(2)
    end

    it 'counts live worker processes' do
      expect(snapshot.processes).to eq(2)
    end

    context 'when no worker process is running' do
      let(:process_count) { 0 }

      it 'flags the missing workers' do
        expect(snapshot).to be_no_processes
      end
    end

    context 'when Redis cannot be reached' do
      before { allow(Sidekiq::Stats).to receive(:new).and_raise(RedisClient::CannotConnectError, 'down') }

      it 'returns an unavailable snapshot instead of raising', :aggregate_failures do
        expect(snapshot).not_to be_available
        expect(snapshot).not_to be_no_processes
        expect(snapshot.queues).to eq([])
      end
    end
  end

  describe '.call' do
    let(:cache) { ActiveSupport::Cache::MemoryStore.new }

    it 'caches an available snapshot so Redis is read once per window' do
      2.times { described_class.call(cache:, now:) }

      expect(Sidekiq::Stats).to have_received(:new).once
    end

    it 'does not cache an unavailable snapshot' do
      allow(Sidekiq::Stats).to receive(:new).and_raise(RedisClient::CannotConnectError, 'down')

      2.times { described_class.call(cache:, now:) }

      expect(Sidekiq::Stats).to have_received(:new).twice
    end

    it 'expires the cached snapshot after the cache window' do
      described_class.call(cache:, now:)
      travel_to(Time.current + described_class::CACHE_TTL + 1.second) { described_class.call(cache:, now:) }

      expect(Sidekiq::Stats).to have_received(:new).twice
    end
  end

  describe '.stalled_after' do
    it 'defaults to ten minutes' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('HOST_JOBS_STALLED_AFTER_MINUTES', nil).and_return(nil)

      expect(described_class.stalled_after).to eq(10.minutes)
    end

    it 'reads HOST_JOBS_STALLED_AFTER_MINUTES' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('HOST_JOBS_STALLED_AFTER_MINUTES', nil).and_return('25')

      expect(described_class.stalled_after).to eq(25.minutes)
    end
  end
end
