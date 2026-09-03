# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::RedactExpiredEventPayloadsJob do
  include ActiveJob::TestHelper

  describe 'queueing' do
    it 'uses the maintenance queue' do
      expect(described_class.new.queue_name).to eq('maintenance')
    end
  end

  describe '#perform' do
    let!(:expired_event) do
      create(
        'better_together/billing/event',
        processed_at: (BetterTogether::Billing::Event::PAYLOAD_RETENTION_DAYS + 1).days.ago,
        payload: {
          'id' => 'evt_expired_123',
          'type' => 'customer.subscription.updated',
          'data' => {
            'object' => {
              'object' => 'subscription',
              'id' => 'sub_expired_123',
              'customer_email' => 'secret@example.com'
            }
          }
        }
      )
    end
    let!(:recent_event) do
      create(
        'better_together/billing/event',
        processed_at: 1.day.ago,
        payload: {
          'id' => 'evt_recent_123',
          'type' => 'customer.subscription.updated',
          'data' => { 'object' => { 'object' => 'subscription', 'id' => 'sub_recent_123', 'customer_email' => 'keep@example.com' } }
        }
      )
    end

    it 'redacts only events older than the retention window' do
      described_class.perform_now

      expect(expired_event.reload.payload_redacted_at).to be_present
      expect(expired_event.payload.dig('data', 'object', 'customer_email')).to be_nil
      expect(recent_event.reload.payload_redacted_at).to be_nil
      expect(recent_event.payload.dig('data', 'object', 'customer_email')).to eq('keep@example.com')
    end
  end
end
