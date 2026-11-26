# frozen_string_literal: true

require 'rails_helper'

# The real Pay::Webhook#process! -> Pay's delegator -> our dispatcher path. Pay hands each processor's
# subscribers a different kind of object; `fake` is delivered as the stored Hash, which the fake adapter reads.
RSpec.describe 'Pay webhook delivery into the billing event log' do # rubocop:disable RSpec/DescribeClass
  include ActiveJob::TestHelper

  include_context 'with clean billing processors'
  include_context 'with billing switched on'

  let!(:host_platform) { configure_host_platform }
  let(:delegator) { Pay::Webhooks::Delegator.new }
  let(:event) { { 'id' => 'evt_flow_1', 'type' => 'fake.invoice.paid' } }

  def webhook(payload = event) = Pay::Webhook.create!(processor: 'fake', event_type: 'invoice.paid', event: payload)

  before do
    allow(BetterTogether).to receive(:report_error)
    allow(Pay::Webhooks).to receive(:delegator).and_return(delegator)
    BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new })
    BetterTogether::Billing::WebhookSubscriptions.instance_variable_set(:@subscribed, nil)
    BetterTogether::Billing::WebhookSubscriptions.subscribe_all!
  end

  # Pay's delegator is a thin wrapper over the process-wide ActiveSupport::Notifications bus, so
  # a subscriber outlives the example that added it.
  after { delegator.unsubscribe('fake.invoice.paid') }

  it 'logs the event once, queues its processing and deletes the Pay row only after that succeeded' do
    row = webhook

    expect { row.process! }.to have_enqueued_job(BetterTogether::Billing::ProcessBillingEventJob)

    expect(Pay::Webhook.exists?(row.id)).to be(false)
    expect(BetterTogether::Billing::Event.where(processor: 'fake', event_id: 'evt_flow_1').count).to eq(1)
  end

  it 'only receives the event types an adapter subscribed to, which is also what Pay ingests' do
    expect(delegator.listening?('fake.invoice.paid')).to be(true)
    expect(delegator.listening?('fake.charge.dispute.created')).to be(false)
  end

  it 'keeps the Pay row, for replay, when the event cannot be attributed to a platform' do
    row = webhook(event.merge('platform_id' => SecureRandom.uuid))

    expect { row.process! }.to raise_error(BetterTogether::Billing::UnattributableWebhookError)
    expect(Pay::Webhook.exists?(row.id)).to be(true)
  end

  describe 'the job that delivers it' do
    it 'discards a refusal, and keeps the row' do
      row = webhook(event.merge('platform_id' => SecureRandom.uuid))

      expect { Pay::Webhooks::ProcessJob.perform_now(row) }.not_to raise_error
      expect(Pay::Webhook.exists?(row.id)).to be(true)
    end

    it 'also discards it when another subscriber failed in the same delivery, which Rails reports as one wrapped error' do
      delegator.subscribe('fake.invoice.paid', ->(_event) { raise 'a Pay handler failed' })
      row = webhook(event.merge('platform_id' => SecureRandom.uuid))

      expect { Pay::Webhooks::ProcessJob.perform_now(row) }.not_to raise_error
      expect(Pay::Webhook.exists?(row.id)).to be(true)
    end

    it 'still raises, to be retried, when only an unrelated subscriber failed' do
      delegator.subscribe('fake.invoice.paid', ->(_event) { raise 'a Pay handler failed' })
      delegator.subscribe('fake.invoice.paid', ->(_event) { raise 'another one failed' })
      row = webhook

      expect { Pay::Webhooks::ProcessJob.perform_now(row) }.to raise_error(StandardError)
      expect(Pay::Webhook.exists?(row.id)).to be(true)
    end

    it 'runs on the billing queue and carries a uuid row through its GlobalID' do
      row = webhook

      queue = [ActiveJob::Base.queue_name_prefix.presence, 'billing'].compact.join(ActiveJob::Base.queue_name_delimiter)

      expect { Pay::Webhooks::ProcessJob.perform_later(row) }.to have_enqueued_job(Pay::Webhooks::ProcessJob).on_queue(queue)
      expect(row.to_global_id.to_s).to include(row.id)
    end
  end
end
