# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::PayExtensions::EncryptedWebhookEvent do
  let(:event) { { 'id' => 'evt_1', 'type' => 'invoice.paid', 'customer_email' => 'private.person@example.test' } }
  let(:webhook) { Pay::Webhook.create!(processor: 'fake_processor', event_type: 'invoice.paid', event:) }

  describe Pay::Webhook do
    it_behaves_like 'encrypts sensitive billing fields' do
      let(:saved_record) { webhook }
      let(:encrypted_fields) { { event: } }
    end

    it 'still lets Pay read the event as a Hash and then delete the row once it is processed' do
      expect(webhook.reload.event).to include('id' => 'evt_1')
      expect(webhook.rehydrated_event).to include('customer_email' => 'private.person@example.test')

      expect { webhook.process! }.to change(described_class, :count).by(-1)
    end

    it 'has no platform column, because rows are transient and hold no tenant data once processed' do
      expect(described_class.column_names).not_to include('platform_id')
    end
  end
end
