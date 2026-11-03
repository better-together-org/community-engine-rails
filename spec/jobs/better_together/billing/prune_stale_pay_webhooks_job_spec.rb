# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::PruneStalePayWebhooksJob do
  def webhook(created_at:)
    Pay::Webhook.create!(processor: 'fake_processor', event_type: 'invoice.paid', event: { 'id' => 'evt', 'type' => 'invoice.paid' },
                         created_at:, updated_at: created_at)
  end

  it 'uses the billing queue' do
    expect(described_class.new.queue_name).to eq('billing')
  end

  it 'deletes deliveries that outlived the retention window and keeps recent ones' do
    old = webhook(created_at: 31.days.ago)
    recent = webhook(created_at: 1.day.ago)

    described_class.perform_now

    expect(Pay::Webhook.exists?(old.id)).to be(false)
    expect(Pay::Webhook.exists?(recent.id)).to be(true)
  end

  it 'follows a longer configured payload retention window' do
    kept_by_default = webhook(created_at: 40.days.ago)
    stub_const('ENV', ENV.to_hash.merge('BT_BILLING_EVENT_PAYLOAD_RETENTION_DAYS' => '60'))

    described_class.perform_now

    expect(Pay::Webhook.exists?(kept_by_default.id)).to be(true)
  end

  it 'never prunes sooner than the delivery job is retried, however short the configured window' do
    still_retrying = webhook(created_at: 10.days.ago)
    past_retries = webhook(created_at: 23.days.ago)
    stub_const('ENV', ENV.to_hash.merge('BT_BILLING_EVENT_PAYLOAD_RETENTION_DAYS' => '7'))

    described_class.perform_now

    expect(Pay::Webhook.exists?(still_retrying.id)).to be(true)
    expect(Pay::Webhook.exists?(past_retries.id)).to be(false)
  end
end
