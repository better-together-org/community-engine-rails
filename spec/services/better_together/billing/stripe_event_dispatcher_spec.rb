# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::StripeEventDispatcher do
  include ActiveJob::TestHelper

  describe '#call' do
    before do
      clear_enqueued_jobs
    end

    it 'enqueues webhook processing with the raw Stripe payload' do
      payload = { 'id' => 'evt_test_123', 'type' => 'customer.subscription.created' }
      event = Struct.new(:payload, keyword_init: true) do
        def to_hash
          payload
        end
      end.new(payload:)

      expect do
        described_class.new.call(event)
      end.to have_enqueued_job(BetterTogether::Billing::ProcessStripeEventJob).with(payload)
    end

    it 'enqueues merchant account webhook payloads' do
      payload = { 'id' => 'evt_acct_123', 'type' => 'account.updated' }
      event = Struct.new(:payload, keyword_init: true) do
        def to_hash
          payload
        end
      end.new(payload:)

      expect do
        described_class.new.call(event)
      end.to have_enqueued_job(BetterTogether::Billing::ProcessStripeEventJob).with(payload)
    end

    it 'enqueues invoice lifecycle webhook payloads' do
      payload = { 'id' => 'evt_invoice_123', 'type' => 'invoice.payment_failed' }
      event = Struct.new(:payload, keyword_init: true) do
        def to_hash
          payload
        end
      end.new(payload:)

      expect do
        described_class.new.call(event)
      end.to have_enqueued_job(BetterTogether::Billing::ProcessStripeEventJob).with(payload)
    end

    it 'processes the payload through the queued job' do
      payload = {
        'id' => 'evt_test_123',
        'type' => 'customer.subscription.created',
        'data' => { 'object' => { 'id' => 'sub_test_123' } }
      }
      event = Struct.new(:payload, keyword_init: true) do
        def to_hash
          payload
        end
      end.new(payload:)
      processor = instance_double(BetterTogether::Billing::StripeEventProcessor, call: true)

      allow(BetterTogether::Billing::StripeEventProcessor).to receive(:new).and_return(processor)

      perform_enqueued_jobs do
        described_class.new.call(event)
      end

      expect(processor).to have_received(:call).with(an_instance_of(Stripe::Event))
    end
  end
end
