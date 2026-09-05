# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederatedContentPullJob do
  describe 'queueing' do
    it 'uses the platform_sync queue' do
      expect(described_class.new.queue_name).to eq('platform_sync')
    end
  end

  describe '#perform' do
    let(:connection) { create(:better_together_platform_connection, :active) }
    let(:ingest_result) do
      BetterTogether::Content::FederatedContentIngestService::Result.new(
        connection:,
        processed_count: 1,
        imported_seeds: [],
        imported_records: [],
        unsupported_seeds: [],
        conflicted_seeds: [],
        conflict_count: 0,
        planting: nil
      )
    end
    let(:pull_result) do
      BetterTogether::FederatedContentPullService::Result.new(
        connection:,
        seeds: [{ 'better_together' => { 'payload' => { 'type' => 'post', 'id' => SecureRandom.uuid,
                                                        'attributes' => { 'title' => 'Remote Post', 'content' => 'Body' } } } }],
        next_cursor: 'cursor-5'
      )
    end
    let(:resolution) do
      BetterTogether::Federation::Transport::Resolution.new(
        tier: :same_instance,
        adapter_class: BetterTogether::Federation::Transport::DirectAdapter
      )
    end

    it 'pulls a batch, ingests inline, and enqueues the next page' do
      allow(BetterTogether::Federation::Transport::TransportResolver).to receive(:call).and_return(resolution)
      allow(BetterTogether::FederatedContentPullService).to receive(:call).and_return(pull_result)
      allow(BetterTogether::Content::FederatedContentIngestService).to receive(:call).and_return(ingest_result)

      expect(BetterTogether::Content::FederatedContentIngestService)
        .to receive(:call).with(connection:, seeds: pull_result.seeds)

      expect do
        described_class.perform_now(platform_connection_id: connection.id, cursor: 'cursor-4')
      end.to have_enqueued_job(described_class)
        .with(platform_connection_id: connection.id, cursor: 'cursor-5', limit: anything)
        .on_queue('platform_sync')
    end

    it 'marks sync failure on pull error' do
      allow(BetterTogether::Federation::Transport::TransportResolver).to receive(:call).and_return(resolution)
      allow(BetterTogether::FederatedContentPullService).to receive(:call).and_raise(StandardError, 'remote failure')

      expect do
        described_class.perform_now(platform_connection_id: connection.id, cursor: 'cursor-7')
      end.to raise_error(StandardError, 'remote failure')

      connection.reload
      expect(connection).to be_sync_failed
      expect(connection.sync_cursor).to eq('cursor-7')
      expect(connection.last_sync_error_message).to eq('remote failure')
    end

    it 'still records sync failure when the in-memory connection is stale at rescue time' do
      allow(BetterTogether::Federation::Transport::TransportResolver).to receive(:call).and_return(resolution)
      allow(BetterTogether::FederatedContentPullService).to receive(:call).and_raise(StandardError, 'concurrent update')

      # Simulate optimistic locking staleness: the first update! (mark_sync_started!)
      # succeeds and bumps lock_version in the DB, leaving the in-memory object stale.
      # Without the reload, mark_sync_failed! would raise StaleObjectError.
      connection.increment!(:lock_version) # DB version is now ahead of the in-memory object

      expect do
        described_class.perform_now(platform_connection_id: connection.id, cursor: 'cursor-9')
      end.to raise_error(StandardError, 'concurrent update')

      connection.reload
      expect(connection).to be_sync_failed
      expect(connection.last_sync_error_message).to eq('concurrent update')
    end

    it 'can run same-instance pulls without invoking the http adapter directly' do
      direct_result = BetterTogether::FederatedContentPullService::Result.new(connection:, seeds: [], next_cursor: nil)

      allow(BetterTogether::Federation::Transport::TransportResolver).to receive(:call).and_return(resolution)
      allow(BetterTogether::Federation::Transport::DirectAdapter).to receive(:call).and_return(direct_result)
      allow(BetterTogether::Federation::Transport::HttpAdapter).to receive(:call)

      described_class.perform_now(platform_connection_id: connection.id)

      expect(BetterTogether::Federation::Transport::DirectAdapter).to have_received(:call)
      expect(BetterTogether::Federation::Transport::HttpAdapter).not_to have_received(:call)
    end

    context 'when the remote rate-limits the pull' do
      let(:rate_limit_error) do
        BetterTogether::Federation::Transport::HttpAdapter::RateLimitedError.new(
          'feed rate-limited', retry_after: 600
        )
      end

      before do
        allow(BetterTogether::Federation::Transport::TransportResolver).to receive(:call).and_return(resolution)
        allow(BetterTogether::FederatedContentPullService).to receive(:call).and_raise(rate_limit_error)
      end

      it 'marks the connection failed with a Retry-After-aware backoff and does not retry the job' do
        expect do
          described_class.perform_now(platform_connection_id: connection.id, cursor: 'cursor-1')
        end.not_to have_enqueued_job(described_class)

        connection.reload
        expect(connection).to be_sync_failed
        expect(Time.zone.parse(connection.sync_backoff_until)).to be > 500.seconds.from_now
      end
    end

    it 'does not clear an existing failure streak on an intermediate (non-final) page' do
      connection.mark_sync_failed!(message: 'earlier failure')
      connection.mark_sync_failed!(message: 'earlier failure')
      streak_before = connection.reload.sync_failure_streak.to_i

      allow(BetterTogether::Federation::Transport::TransportResolver).to receive(:call).and_return(resolution)
      allow(BetterTogether::FederatedContentPullService).to receive(:call).and_return(pull_result) # next_cursor present
      allow(BetterTogether::Content::FederatedContentIngestService).to receive(:call).and_return(ingest_result)

      described_class.perform_now(platform_connection_id: connection.id)

      connection.reload
      expect(connection).to be_sync_succeeded
      expect(connection.sync_failure_streak.to_i).to eq(streak_before)
    end

    it 'clears the failure streak when the final page completes' do
      connection.mark_sync_failed!(message: 'earlier failure')
      final_result = BetterTogether::FederatedContentPullService::Result.new(connection:, seeds: [], next_cursor: nil)

      allow(BetterTogether::Federation::Transport::TransportResolver).to receive(:call).and_return(resolution)
      allow(BetterTogether::FederatedContentPullService).to receive(:call).and_return(final_result)

      described_class.perform_now(platform_connection_id: connection.id)

      expect(connection.reload.sync_failure_streak.to_i).to eq(0)
    end

    it 'records a sync summary when ingest completed with mirrored content conflicts' do
      conflict_result = BetterTogether::Content::FederatedContentIngestService::Result.new(
        connection:,
        processed_count: 1,
        imported_seeds: [],
        imported_records: [],
        unsupported_seeds: [],
        conflicted_seeds: [{ 'seed_type' => 'post' }],
        conflict_count: 1,
        planting: nil
      )

      allow(BetterTogether::Federation::Transport::TransportResolver).to receive(:call).and_return(resolution)
      allow(BetterTogether::FederatedContentPullService).to receive(:call).and_return(pull_result)
      allow(BetterTogether::Content::FederatedContentIngestService).to receive(:call).and_return(conflict_result)

      described_class.perform_now(platform_connection_id: connection.id)

      connection.reload
      expect(connection).to be_sync_succeeded
      expect(connection.last_sync_error_message).to eq(
        I18n.t('better_together.federation.ingest.sync_summary', count: 1)
      )
    end
  end
end
