# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederatedContentIngestJob do
  describe 'queueing' do
    it 'uses the platform_sync queue' do
      expect(described_class.new.queue_name).to eq('platform_sync')
    end
  end

  describe '#perform' do
    let(:connection) { create(:better_together_platform_connection, :active) }
    let(:seeds) do
      [
        {
          'better_together' => {
            'payload' => {
              'type' => 'post',
              'id' => SecureRandom.uuid,
              'attributes' => {
                'title' => 'Remote Post',
                'content' => 'Post content',
                'identifier' => 'remote-post'
              }
            }
          }
        }
      ]
    end

    it 'raises ArgumentError when seeds exceed MAX_SEEDS_PER_JOB' do
      oversized_seeds = Array.new(described_class::MAX_SEEDS_PER_JOB + 1) { seeds.first }

      expect do
        described_class.perform_now(platform_connection_id: connection.id, seeds: oversized_seeds)
      end.to raise_error(ArgumentError, /seeds payload too large/)
    end

    it 'delegates to the federated content ingest service' do
      allow(BetterTogether::Content::FederatedContentIngestService).to receive(:call).and_return(
        BetterTogether::Content::FederatedContentIngestService::Result.new(
          connection:,
          processed_count: 1,
          imported_seeds: [],
          imported_records: [],
          unsupported_seeds: [],
          planting: nil
        )
      )

      expect(BetterTogether::Content::FederatedContentIngestService).to receive(:call).with(connection:, seeds:)

      described_class.perform_now(platform_connection_id: connection.id, seeds:)
    end

    it 'marks sync status around a successful ingest' do
      allow(BetterTogether::Content::FederatedContentIngestService).to receive(:call).and_return(
        BetterTogether::Content::FederatedContentIngestService::Result.new(
          connection:,
          processed_count: 1,
          imported_seeds: [],
          imported_records: [],
          unsupported_seeds: [],
          planting: nil
        )
      )

      described_class.perform_now(platform_connection_id: connection.id, seeds:, sync_cursor: 'cursor-1')

      connection.reload
      expect(connection).to be_sync_succeeded
      expect(connection.sync_cursor).to eq('cursor-1')
      expect(connection.last_sync_item_count).to eq(1)
    end

    it 'marks sync failure and re-raises the error' do
      allow(BetterTogether::Content::FederatedContentIngestService).to receive(:call).and_raise(StandardError, 'boom')

      expect do
        described_class.perform_now(platform_connection_id: connection.id, seeds:, sync_cursor: 'cursor-2')
      end.to raise_error(StandardError, 'boom')

      connection.reload
      expect(connection).to be_sync_failed
      expect(connection.sync_cursor).to eq('cursor-2')
      expect(connection.last_sync_error_message).to eq('boom')
    end
  end
end
