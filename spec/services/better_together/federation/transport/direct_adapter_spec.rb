# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Federation::Transport::DirectAdapter do
  describe '.call' do
    let(:connection) { create(:better_together_platform_connection, :active) }
    let(:export_result) do
      BetterTogether::Content::FederatedContentExportService::Result.new(
        connection,
        [{ 'seed' => 'payload' }],
        'cursor-2'
      )
    end

    it 'delegates to the export service and returns pull-service result shape' do
      allow(BetterTogether::Content::FederatedContentExportService)
        .to receive(:call)
        .with(connection:, cursor: 'cursor-1', limit: 25)
        .and_return(export_result)

      result = described_class.call(connection:, cursor: 'cursor-1', limit: 25)

      expect(result).to be_a(BetterTogether::FederatedContentPullService::Result)
      expect(result.connection).to eq(connection)
      expect(result.seeds).to eq(export_result.seeds)
      expect(result.next_cursor).to eq('cursor-2')
    end
  end
end
