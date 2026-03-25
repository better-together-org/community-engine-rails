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

    it 'can run same-instance pulls without invoking the http adapter directly' do
      direct_result = BetterTogether::FederatedContentPullService::Result.new(connection:, seeds: [], next_cursor: nil)

      allow(BetterTogether::Federation::Transport::TransportResolver).to receive(:call).and_return(resolution)
      allow(BetterTogether::Federation::Transport::DirectAdapter).to receive(:call).and_return(direct_result)
      allow(BetterTogether::Federation::Transport::HttpAdapter).to receive(:call)

      described_class.perform_now(platform_connection_id: connection.id)

      expect(BetterTogether::Federation::Transport::DirectAdapter).to have_received(:call)
      expect(BetterTogether::Federation::Transport::HttpAdapter).not_to have_received(:call)
    end
  end
end
