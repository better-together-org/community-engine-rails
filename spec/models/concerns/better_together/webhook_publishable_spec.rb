# frozen_string_literal: true

require 'rails_helper'

# Define a test class at load time so it is available in all parallel workers
module BetterTogether
  class TestPublishableModel < ApplicationRecord # rubocop:disable Lint/ConstantDefinitionInBlock
    self.table_name = 'better_together_communities'
    self.inheritance_column = :_type_disabled # Avoid STI conflicts with Community
    include BetterTogether::WebhookPublishable
  end
end

RSpec.describe BetterTogether::WebhookPublishable do
  let(:test_class) { BetterTogether::TestPublishableModel }

  describe '.webhook_event_prefix' do
    it 'returns the demodulized underscored model name' do
      expect(test_class.webhook_event_prefix).to eq('test_publishable_model')
    end
  end

  describe '.webhook_events' do
    it 'defaults to created, updated, destroyed' do
      expect(test_class._webhook_event_types).to eq(%i[created updated destroyed])
    end

    it 'can be customized' do
      test_class.webhook_events(:created, :updated)
      expect(test_class._webhook_event_types).to eq(%i[created updated])
    ensure
      test_class._webhook_event_types = %i[created updated destroyed]
    end
  end

  describe 'callback registration' do
    it 'registers after_create_commit callback' do
      callbacks = test_class._commit_callbacks.select { |cb| cb.filter == :publish_webhook_created }
      expect(callbacks).not_to be_empty
    end

    it 'registers after_update_commit callback' do
      callbacks = test_class._commit_callbacks.select { |cb| cb.filter == :publish_webhook_updated }
      expect(callbacks).not_to be_empty
    end

    it 'registers after_destroy_commit callback' do
      callbacks = test_class._commit_callbacks.select { |cb| cb.filter == :publish_webhook_destroyed }
      expect(callbacks).not_to be_empty
    end
  end

  describe 'publish_webhook_event methods' do
    let(:instance) { test_class.new }

    context 'when event type is not configured' do
      it 'does not publish when event type is excluded' do
        test_class._webhook_event_types = %i[updated]
        expect(BetterTogether::WebhookEndpoint).not_to receive(:for_event)
        instance.send(:publish_webhook_created)
      ensure
        test_class._webhook_event_types = %i[created updated destroyed]
      end
    end

    context 'when event type is configured' do
      let(:person) { create(:better_together_person) }

      it 'creates webhook deliveries for subscribed endpoints' do
        endpoint = create(:better_together_webhook_endpoint,
                          person: person,
                          events: ['test_publishable_model.created'])
        # Stub the instance to have an id and attributes
        allow(instance).to receive(:id).and_return(SecureRandom.uuid)
        allow(instance).to receive_messages(created_at: Time.current, updated_at: Time.current)

        instance.send(:publish_webhook_event, 'created')

        delivery = BetterTogether::WebhookDelivery.last
        expect(delivery).to be_present
        expect(delivery.event).to eq('test_publishable_model.created')
        expect(delivery.webhook_endpoint).to eq(endpoint)
        expect(delivery.status).to eq('pending')
      end
    end

    context 'when no endpoints are subscribed' do
      it 'does not create any deliveries' do
        BetterTogether::WebhookEndpoint.destroy_all
        allow(instance).to receive(:id).and_return(SecureRandom.uuid)

        expect do
          instance.send(:publish_webhook_event, 'created')
        end.not_to change(BetterTogether::WebhookDelivery, :count)
      end
    end
  end

  describe '#webhook_payload' do
    let(:instance) { test_class.new }
    let(:fake_id) { SecureRandom.uuid }

    before do
      allow(instance).to receive(:id).and_return(fake_id)
      allow(instance).to receive_messages(created_at: Time.current, updated_at: Time.current)
    end

    it 'includes event name, timestamp, and data' do
      payload = instance.send(:webhook_payload, 'created')

      expect(payload[:event]).to eq('test_publishable_model.created')
      expect(payload[:timestamp]).to be_a(String)
      expect(payload[:data][:id]).to eq(fake_id)
      expect(payload[:data][:type]).to eq('BetterTogether::TestPublishableModel')
    end
  end

  describe '#webhook_attributes' do
    let(:instance) { test_class.new }
    let(:now) { Time.current }

    before do
      allow(instance).to receive_messages(created_at: now, updated_at: now, identifier: 'test-id', privacy: 'public')
    end

    it 'includes standard attributes when present' do
      attrs = instance.send(:webhook_attributes)

      expect(attrs).to include(:created_at, :updated_at, :identifier, :privacy)
    end

    it 'excludes nil attributes' do
      allow(instance).to receive_messages(identifier: nil, privacy: nil)
      attrs = instance.send(:webhook_attributes)

      # name, slug may naturally be nil — all returned values should be non-nil
      attrs.each_value do |v|
        expect(v).not_to be_nil
      end
    end
  end

  describe 'error handling' do
    let(:instance) { test_class.new }
    let(:person) { create(:better_together_person) }

    it 'logs errors without raising' do
      endpoint = create(:better_together_webhook_endpoint, person: person,
                                                           events: ['test_publishable_model.updated'])

      allow(instance).to receive(:id).and_return(SecureRandom.uuid)
      allow(instance).to receive_messages(created_at: Time.current, updated_at: Time.current)

      # Stub the endpoint's deliveries to raise on create!
      deliveries_double = double('deliveries') # rubocop:disable RSpec/VerifiedDoubles
      allow(deliveries_double).to receive(:create!).and_raise(StandardError, 'DB error')
      allow(endpoint).to receive(:webhook_deliveries).and_return(deliveries_double)
      allow(BetterTogether::WebhookEndpoint).to receive(:for_event)
        .with('test_publishable_model.updated')
        .and_return([endpoint])

      expect(Rails.logger).to receive(:error).with(/Failed to publish webhook event/)
      expect { instance.send(:publish_webhook_event, 'updated') }.not_to raise_error
    end
  end
end
