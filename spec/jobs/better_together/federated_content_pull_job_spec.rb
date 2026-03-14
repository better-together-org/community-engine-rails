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

    it 'pulls a batch, ingests inline, and enqueues the next page' do
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
      allow(BetterTogether::FederatedContentPullService).to receive(:call).and_raise(StandardError, 'remote failure')

      expect do
        described_class.perform_now(platform_connection_id: connection.id, cursor: 'cursor-7')
      end.to raise_error(StandardError, 'remote failure')

      connection.reload
      expect(connection).to be_sync_failed
      expect(connection.sync_cursor).to eq('cursor-7')
      expect(connection.last_sync_error_message).to eq('remote failure')
    end
  end
end
