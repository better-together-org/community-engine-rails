# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::StripeEventPayloadSanitizer do
  describe '#call' do
    it 'retains identifiers while removing extraneous object attributes' do
      payload = {
        'id' => 'evt_payload_123',
        'type' => 'customer.subscription.updated',
        'created' => 1_777_777_777,
        'request' => { 'id' => 'req_123', 'idempotency_key' => 'ik_123', 'foo' => 'bar' },
        'data' => {
          'object' => {
            'object' => 'subscription',
            'id' => 'sub_payload_123',
            'customer' => 'cus_payload_123',
            'status' => 'active',
            'metadata' => { 'bt_community_id' => 'community-123' },
            'customer_email' => 'secret@example.com',
            'items' => {
              'object' => 'list',
              'data' => [
                {
                  'id' => 'si_123',
                  'object' => 'subscription_item',
                  'price' => { 'id' => 'price_123', 'object' => 'price', 'unit_amount' => 1000 }
                }
              ]
            }
          },
          'previous_attributes' => {
            'status' => 'past_due',
            'customer_email' => 'secret@example.com'
          }
        }
      }

      sanitized = described_class.new.call(payload)

      expect(sanitized).to include(
        'id' => 'evt_payload_123',
        'type' => 'customer.subscription.updated',
        'bt_payload_redacted' => true,
        'bt_payload_redaction_version' => 1
      )
      expect(sanitized['request']).to eq({ 'id' => 'req_123', 'idempotency_key' => 'ik_123' })
      expect(sanitized.dig('data', 'object', 'customer_email')).to be_nil
      expect(sanitized.dig('data', 'previous_attributes')).to eq({ 'status' => 'past_due' })
      expect(sanitized.dig('data', 'object', 'items', 'data')).to eq(
        [{ 'id' => 'si_123', 'object' => 'subscription_item', 'price' => { 'id' => 'price_123', 'object' => 'price' } }]
      )
    end
  end
end
