# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederatedContentIngestJob, type: :job do
  describe '#perform' do
    let(:connection) { create(:better_together_platform_connection, :active) }
    let(:items) do
      [
        {
          type: 'post',
          id: SecureRandom.uuid,
          attributes: {
            title: 'Remote Post',
            content: 'Post content',
            identifier: 'remote-post'
          }
        }
      ]
    end

    it 'delegates to the federated content ingest service' do
      expect(BetterTogether::Content::FederatedContentIngestService).to receive(:call).with(
        connection:,
        items:
      )

      described_class.perform_now(platform_connection_id: connection.id, items:)
    end
  end
end
