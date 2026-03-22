# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::WebhookDeliveryJob do
  include ActiveJob::TestHelper

  let(:endpoint) { create(:better_together_webhook_endpoint, url: 'https://example.com/webhooks') }
  let(:delivery) do
    create(:better_together_webhook_delivery,
           webhook_endpoint: endpoint,
           event: 'community.created',
           payload: { 'id' => SecureRandom.uuid, 'name' => 'Test Community' })
  end

  describe '#perform' do
    context 'when endpoint is active and response is successful' do
      before do
        stub_request(:post, 'https://example.com/webhooks')
          .to_return(status: 200, body: '{"ok":true}')
      end

      it 'delivers the webhook and marks as delivered' do
        described_class.perform_now(delivery.id)
        delivery.reload

        expect(delivery.status).to eq('delivered')
        expect(delivery.response_code).to eq(200)
        expect(delivery.delivered_at).to be_present
      end

      it 'sends correct headers' do
        described_class.perform_now(delivery.id)

        expect(WebMock).to(have_requested(:post, 'https://example.com/webhooks')
          .with do |req|
            req.headers['X-Bt-Webhook-Event'] == 'community.created' &&
              req.headers['X-Bt-Webhook-Delivery-Id'] == delivery.id &&
              req.headers['Content-Type'] == 'application/json' &&
              req.headers['X-Bt-Webhook-Signature'].present? &&
              req.headers['X-Bt-Webhook-Timestamp'].present? &&
              req.headers['User-Agent'].start_with?('BetterTogether/')
          end)
      end

      it 'signs the payload with HMAC-SHA256' do
        described_class.perform_now(delivery.id)

        expect(WebMock).to(have_requested(:post, 'https://example.com/webhooks')
          .with do |req|
            signature = req.headers['X-Bt-Webhook-Signature']
            timestamp = req.headers['X-Bt-Webhook-Timestamp']
            expected_payload = "#{timestamp}.#{req.body}"
            expected_sig = OpenSSL::HMAC.hexdigest('sha256', endpoint.secret, expected_payload)
            signature == expected_sig
          end)
      end
    end

    context 'when endpoint is inactive' do
      let(:endpoint) { create(:better_together_webhook_endpoint, :inactive, url: 'https://example.com/webhooks') }

      it 'marks the delivery as failed without making HTTP request' do
        described_class.perform_now(delivery.id)
        delivery.reload

        expect(delivery.status).to eq('failed')
        expect(delivery.response_body).to include('inactive')
        expect(WebMock).not_to have_requested(:post, 'https://example.com/webhooks')
      end
    end

    context 'when response is non-2xx' do
      before do
        stub_request(:post, 'https://example.com/webhooks')
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'marks the delivery as retrying' do
        described_class.perform_now(delivery.id)

        delivery.reload
        expect(delivery.status).to eq('retrying')
      end
    end

    context 'when delivery record does not exist' do
      it 'logs a warning and does not raise' do
        expect do
          described_class.perform_now(SecureRandom.uuid)
        end.not_to raise_error
      end
    end
  end

  describe 'job configuration' do
    it 'uses the webhooks queue' do
      expect(described_class.new.queue_name).to eq('webhooks')
    end

    it 'is enqueued correctly' do
      expect do
        described_class.perform_later(delivery.id)
      end.to have_enqueued_job(described_class).with(delivery.id)
    end
  end
end
