# frozen_string_literal: true

require 'rails_helper'

# @hermetic
RSpec.describe BetterTogether::FederationConnectionProvisioningService do
  let(:source_platform) { create(:better_together_platform) }
  let(:target_platform) { create(:better_together_platform) }

  describe '.call' do
    context 'with default policies' do
      it 'creates a pending connection' do
        result = described_class.call(
          source_platform:,
          target_platform:
        )

        expect(result).to be_success
        expect(result.connection).to be_persisted
        expect(result.connection.status).to eq('pending')
        expect(result.connection.source_platform).to eq(source_platform)
        expect(result.connection.target_platform).to eq(target_platform)
      end
    end

    context 'with custom policies' do
      it 'applies the supplied policies to the connection' do
        result = described_class.call(
          source_platform:,
          target_platform:,
          policies: {
            content_sharing_policy: 'mirror_network_feed',
            federation_auth_policy: 'api_read',
            allow_content_read_scope: true
          }
        )

        expect(result).to be_success
        expect(result.connection.content_sharing_policy).to eq('mirror_network_feed')
        expect(result.connection.allow_content_read_scope).to be(true)
      end
    end

    context 'when activate: true' do
      it 'sets the connection status to active' do
        result = described_class.call(
          source_platform:,
          target_platform:,
          activate: true,
          enqueue_sync: false
        )

        expect(result).to be_success
        expect(result.connection.status).to eq('active')
      end

      it 'enqueues FederatedSyncScanJob when enqueue_sync is true' do
        expect(BetterTogether::FederatedSyncScanJob).to receive(:perform_later)

        described_class.call(
          source_platform:,
          target_platform:,
          activate: true,
          enqueue_sync: true
        )
      end
    end

    context 'when idempotent' do
      it 'updates the existing connection on re-run with same platform pair' do
        first  = described_class.call(source_platform:, target_platform:)
        second = described_class.call(
          source_platform:,
          target_platform:,
          policies: { content_sharing_policy: 'mirror_network_feed' }
        )

        expect(second).to be_success
        expect(second.connection.id).to eq(first.connection.id)
        expect(second.connection.content_sharing_policy).to eq('mirror_network_feed')
      end
    end
  end
end
