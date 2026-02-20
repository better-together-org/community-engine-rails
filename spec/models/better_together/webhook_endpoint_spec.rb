# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::WebhookEndpoint do
  subject(:webhook_endpoint) { build(:better_together_webhook_endpoint) }

  describe 'associations' do
    it { is_expected.to belong_to(:person).class_name('BetterTogether::Person') }
    it { is_expected.to belong_to(:oauth_application).class_name('BetterTogether::OauthApplication').optional }
    it { is_expected.to have_many(:webhook_deliveries).class_name('BetterTogether::WebhookDelivery').dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_presence_of(:name) }

    context 'with secret presence on update' do
      subject(:persisted_endpoint) { create(:better_together_webhook_endpoint) }

      it 'validates secret is present on update' do
        persisted_endpoint.secret = ''
        expect(persisted_endpoint).not_to be_valid
        expect(persisted_endpoint.errors[:secret]).to include("can't be blank")
      end
    end

    context 'url format' do
      it 'accepts valid HTTPS URLs' do
        webhook_endpoint.url = 'https://example.com/webhooks'
        expect(webhook_endpoint).to be_valid
      end

      it 'accepts valid HTTP URLs' do
        webhook_endpoint.url = 'http://localhost:5678/webhook/handler'
        expect(webhook_endpoint).to be_valid
      end

      it 'rejects private/localhost URLs when private targets are disabled' do
        allow(described_class).to receive(:allow_private_targets?).and_return(false)

        webhook_endpoint.url = 'http://127.0.0.1:5678/webhook/handler'
        expect(webhook_endpoint).not_to be_valid
      end

      it 'rejects invalid URLs' do
        webhook_endpoint.url = 'not-a-url'
        expect(webhook_endpoint).not_to be_valid
      end
    end

    context 'event name validation' do
      it 'accepts valid event names' do
        webhook_endpoint.events = %w[community.created post.updated]
        expect(webhook_endpoint).to be_valid
      end

      it 'rejects invalid event names' do
        webhook_endpoint.events = ['INVALID']
        expect(webhook_endpoint).not_to be_valid
        expect(webhook_endpoint.errors[:events]).to be_present
      end

      it 'allows empty events array (subscribe to all)' do
        webhook_endpoint.events = []
        expect(webhook_endpoint).to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:active_endpoint) { create(:better_together_webhook_endpoint, active: true) }
    let!(:inactive_endpoint) { create(:better_together_webhook_endpoint, :inactive) }

    describe '.active' do
      it 'returns only active endpoints' do
        expect(described_class.active).to include(active_endpoint)
        expect(described_class.active).not_to include(inactive_endpoint)
      end
    end

    describe '.for_event' do
      let!(:all_events_endpoint) { create(:better_together_webhook_endpoint, events: []) }
      let!(:specific_endpoint) { create(:better_together_webhook_endpoint, events: %w[community.created]) }
      let!(:other_endpoint) { create(:better_together_webhook_endpoint, events: %w[post.created]) }

      it 'returns endpoints subscribed to all events' do
        results = described_class.for_event('community.created')
        expect(results).to include(all_events_endpoint)
      end

      it 'returns endpoints subscribed to the specific event' do
        results = described_class.for_event('community.created')
        expect(results).to include(specific_endpoint)
      end

      it 'excludes endpoints subscribed to different events' do
        results = described_class.for_event('community.created')
        expect(results).not_to include(other_endpoint)
      end
    end
  end

  describe '#subscribed_to?' do
    it 'returns true when events is empty (subscribes to all)' do
      webhook_endpoint.events = []
      expect(webhook_endpoint.subscribed_to?('community.created')).to be true
    end

    it 'returns true when event is in the events list' do
      webhook_endpoint.events = %w[community.created post.updated]
      expect(webhook_endpoint.subscribed_to?('community.created')).to be true
    end

    it 'returns false when event is not in the events list' do
      webhook_endpoint.events = %w[post.created]
      expect(webhook_endpoint.subscribed_to?('community.created')).to be false
    end
  end

  describe 'secret generation' do
    it 'auto-generates a secret on create when blank' do
      endpoint = build(:better_together_webhook_endpoint, secret: nil)
      endpoint.valid?
      expect(endpoint.secret).to be_present
    end

    it 'preserves provided secret' do
      custom_secret = SecureRandom.hex(32)
      endpoint = build(:better_together_webhook_endpoint, secret: custom_secret)
      endpoint.valid?
      expect(endpoint.secret).to eq(custom_secret)
    end
  end
end
