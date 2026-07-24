# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::WebhookDelivery do
  subject(:webhook_delivery) { build(:better_together_webhook_delivery) }

  describe 'associations' do
    it { is_expected.to belong_to(:webhook_endpoint).class_name('BetterTogether::WebhookEndpoint') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:event) }
    it { is_expected.to validate_presence_of(:status) }

    it 'validates status inclusion' do
      expect { webhook_delivery.status = 'invalid' }.to raise_error(ArgumentError)
    end

    %w[pending delivered failed retrying].each do |valid_status|
      it "accepts #{valid_status} status" do
        webhook_delivery.status = valid_status
        expect(webhook_delivery).to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:pending) { create(:better_together_webhook_delivery) }
    let!(:delivered) { create(:better_together_webhook_delivery, :delivered) }
    let!(:failed) { create(:better_together_webhook_delivery, :failed) }

    describe '.pending' do
      it 'returns only pending deliveries' do
        expect(described_class.pending).to include(pending)
        expect(described_class.pending).not_to include(delivered, failed)
      end
    end

    describe '.delivered' do
      it 'returns only delivered deliveries' do
        expect(described_class.delivered).to include(delivered)
        expect(described_class.delivered).not_to include(pending, failed)
      end
    end

    describe '.failed' do
      it 'returns only failed deliveries' do
        expect(described_class.failed).to include(failed)
        expect(described_class.failed).not_to include(pending, delivered)
      end
    end

    describe '.for_platform' do
      let(:platform_a) { create(:better_together_platform, host: false) }
      let(:platform_b) { create(:better_together_platform, host: false) }
      let!(:delivery_a) do
        create(:webhook_delivery, webhook_endpoint: create(:webhook_endpoint, platform: platform_a),
                                  platform_id: platform_a.id)
      end
      let!(:delivery_b) do
        create(:webhook_delivery, webhook_endpoint: create(:webhook_endpoint, platform: platform_b),
                                  platform_id: platform_b.id)
      end

      it 'returns deliveries for the given platform' do
        expect(described_class.for_platform(platform_a)).to include(delivery_a)
        expect(described_class.for_platform(platform_a)).not_to include(delivery_b)
      end

      it 'returns deliveries for platform B when queried' do
        expect(described_class.for_platform(platform_b)).to include(delivery_b)
        expect(described_class.for_platform(platform_b)).not_to include(delivery_a)
      end
    end
  end

  describe '#mark_delivered!' do
    let(:delivery) { create(:better_together_webhook_delivery) }

    it 'updates status to delivered' do
      delivery.mark_delivered!(code: 200, body: '{"ok":true}')
      expect(delivery.reload.status).to eq('delivered')
      expect(delivery.response_code).to eq(200)
      expect(delivery.delivered_at).to be_present
      expect(delivery.attempts).to eq(1)
    end

    it 'truncates long response bodies' do
      long_body = 'x' * 2000
      delivery.mark_delivered!(code: 200, body: long_body)
      expect(delivery.reload.response_body.length).to be <= 1003 # 1000 + "..."
    end
  end

  describe '#mark_failed!' do
    let(:delivery) { create(:better_together_webhook_delivery) }

    it 'updates status to failed' do
      delivery.mark_failed!(code: 500, body: 'Server Error')
      expect(delivery.reload.status).to eq('failed')
      expect(delivery.response_code).to eq(500)
      expect(delivery.attempts).to eq(1)
    end
  end

  describe '#mark_retrying!' do
    let(:delivery) { create(:better_together_webhook_delivery) }

    it 'updates status to retrying and increments attempts' do
      delivery.mark_retrying!
      expect(delivery.reload.status).to eq('retrying')
      expect(delivery.attempts).to eq(1)
    end
  end

  describe 'platform_id derivation from endpoint' do
    let(:platform_a) { create(:better_together_platform, host: false) }
    let(:endpoint_a) { create(:webhook_endpoint, platform: platform_a) }

    it 'derives platform_id from the endpoint when created via the association without an explicit value' do
      delivery = endpoint_a.webhook_deliveries.create!(event: 'community.created', payload: {}, status: 'pending')

      expect(delivery.platform_id).to eq(platform_a.id)
    end

    it 'leaves platform_id nil when the endpoint itself has none' do
      endpoint_a.update_column(:platform_id, nil)
      delivery = endpoint_a.webhook_deliveries.build(event: 'community.created', payload: {}, status: 'pending')

      delivery.valid?

      expect(delivery.platform_id).to be_nil
    end
  end

  describe 'platform integrity' do
    let(:platform_a) { create(:better_together_platform, host: false) }
    let(:platform_b) { create(:better_together_platform, host: false) }
    let(:endpoint_a) { create(:webhook_endpoint, platform: platform_a) }
    let(:endpoint_b) { create(:webhook_endpoint, platform: platform_b) }

    describe 'platform_matches_endpoint validation' do
      it 'rejects platform_id mismatching endpoint platform' do
        delivery = build(:webhook_delivery, webhook_endpoint: endpoint_a, platform_id: platform_b.id)
        expect(delivery).not_to be_valid
        expect(delivery.errors[:platform_id]).to include('must match webhook endpoint platform')
      end

      it 'allows platform_id matching endpoint platform' do
        delivery = build(:webhook_delivery, webhook_endpoint: endpoint_a, platform_id: platform_a.id)
        expect(delivery).to be_valid
      end

      it 'allows nil platform_id if endpoint has nil platform' do
        endpoint_a.update_column(:platform_id, nil)
        delivery = build(:webhook_delivery, webhook_endpoint: endpoint_a, platform_id: nil)
        expect(delivery).to be_valid
      end

      it 'skips validation if endpoint platform is nil' do
        endpoint_a.update_column(:platform_id, nil)
        delivery = build(:webhook_delivery, webhook_endpoint: endpoint_a, platform_id: platform_a.id)
        expect(delivery).to be_valid
      end
    end

    describe 'cross-platform safety' do
      it 'prevents platform B delivery from accessing platform A endpoint' do
        delivery_b = build(:webhook_delivery, webhook_endpoint: endpoint_a, platform_id: platform_b.id)
        expect(delivery_b).not_to be_valid
      end

      it 'allows each platform to have independent deliveries' do
        delivery_a1 = create(:webhook_delivery, webhook_endpoint: endpoint_a, platform_id: platform_a.id)
        delivery_a2 = create(:webhook_delivery, webhook_endpoint: endpoint_a, platform_id: platform_a.id)

        expect([delivery_a1, delivery_a2]).to all(be_valid)
      end
    end
  end
end
