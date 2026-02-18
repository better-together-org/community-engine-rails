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
      webhook_delivery.status = 'invalid'
      expect(webhook_delivery).not_to be_valid
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
end
