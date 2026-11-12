# frozen_string_literal: true

# @hermetic
require 'rails_helper'

# What reaches billing through the processor webhook address, and what does not.
#
# Signature checking is done by Pay and the vendor gem (the engine bundles none), so the HTTP half
# asserts the outcome that must hold in every setup: a forged or unsigned request is never accepted
# (4xx, whether the route is absent or Pay refuses it) and changes nothing. The delivery half starts
# where a verified request ends, at the stored Pay::Webhook row.
RSpec.describe 'Billing webhook security' do # rubocop:disable RSpec/DescribeClass
  include ActiveJob::TestHelper

  include_context 'with orders fixtures'

  let(:processors) { %w[stripe braintree paddle_billing paddle_classic lemon_squeezy] }
  let(:forged_headers) do
    { 'CONTENT_TYPE' => 'application/json', 'HTTP_STRIPE_SIGNATURE' => 't=1,v1=forged',
      'HTTP_PADDLE_SIGNATURE' => 'ts=1;h1=forged', 'HTTP_X_SIGNATURE' => 'forged' }
  end
  let(:forged_body) do
    { id: 'evt_forged', type: 'invoice.paid', platform_id: host_platform.id, data: { object: { amount_paid: 1 } } }.to_json
  end
  let(:order) { create(:better_together_billing_order, :awaiting_payment, platform: host_platform, total_cents: 4500) }
  let!(:payment) { create(:better_together_billing_payment, order:, platform_id: host_platform.id, status: 'pending') }

  # The status answered. No route (the dummy raises RoutingError for it) is a 404.
  def post_webhook(processor, headers: forged_headers)
    post "/pay/webhooks/#{processor}", params: forged_body, headers: headers
    response.status
  rescue ActionController::RoutingError
    404
  end

  def get_status(path)
    get path
    3.times { follow_redirect! if response.redirect? }
    response.status
  rescue ActionController::RoutingError
    404
  end

  def delivered(payload) = Pay::Webhook.create!(processor: 'fake', event_type: 'invoice.paid', event: payload)

  def events = BetterTogether::Billing::Event.where(processor: 'fake', event_id: 'evt_secure_1')

  def state
    [BetterTogether::Billing::Event.count, Pay::Webhook.count, order.reload.status, payment.reload.status, order.paid_at]
  end

  describe 'a forged or unsigned request' do
    it 'is never accepted and changes nothing, for every processor address', :aggregate_failures do
      before = state

      processors.each do |processor|
        status = post_webhook(processor)
        expect(status).to be_between(400, 499), "#{processor} answered #{status}"
      end

      expect(state).to eq(before)
    end

    it 'is refused with no signature header at all' do
      before = state

      statuses = processors.map { |processor| post_webhook(processor, headers: { 'CONTENT_TYPE' => 'application/json' }) }

      expect(state).to eq(before)
      expect(statuses).to all(be_between(400, 499))
    end

    it 'cannot reach Pay\'s payment page through the mount' do
      expect(get_status('/pay/payments/pi_forged')).to be_between(400, 499)
    end
  end

  describe 'a delivery Pay accepted' do
    let(:delegator) { Pay::Webhooks::Delegator.new }
    let(:event) { { 'id' => 'evt_secure_1', 'type' => 'fake.invoice.paid', 'outcome' => 'processed' } }

    before do
      allow(BetterTogether).to receive(:report_error)
      allow(Pay::Webhooks).to receive(:delegator).and_return(delegator)
      BetterTogether::Billing.register_processor(:fake, -> { adapter })
      BetterTogether::Billing::WebhookSubscriptions.instance_variable_set(:@subscribed, nil)
      BetterTogether::Billing::WebhookSubscriptions.subscribe_all!
    end

    after { delegator.unsubscribe('fake.invoice.paid') }

    it 'is logged once and processed once' do
      perform_enqueued_jobs { delivered(event).process! }

      expect(events.sole).to have_attributes(platform_id: host_platform.id, processing_status: 'processed', attempt_count: 1)
      expect(adapter.calls.count { |call| call.first == :process_event }).to eq(1)
    end

    it 'is idempotent when the same event id is delivered again, even after it was processed' do
      perform_enqueued_jobs { delivered(event).process! }
      perform_enqueued_jobs { delivered(event).process! }
      perform_enqueued_jobs { delivered(event).process! }

      expect(events.count).to eq(1)
      expect(events.sole).to have_attributes(processing_status: 'processed', attempt_count: 1)
      expect(adapter.calls.count { |call| call.first == :process_event }).to eq(1)
    end

    it 'is refused, and logs nothing, when it names a platform that has no billing configured' do
      row = delivered(event.merge('platform_id' => SecureRandom.uuid))

      expect { row.process! }.to raise_error(BetterTogether::Billing::UnattributableWebhookError)
      expect(events).to be_empty
    end

    it 'cannot be logged against a second platform under the same event id' do
      perform_enqueued_jobs { delivered(event).process! }
      other = create(:better_together_platform)

      expect do
        BetterTogether::Billing::EventIngest.call(processor: :fake, platform: other, event_id: 'evt_secure_1',
                                                  event_type: 'fake.invoice.paid', payload: event)
      end.to raise_error(BetterTogether::Billing::EventIngest::PlatformConflictError)
      expect(events.pluck(:platform_id)).to eq([host_platform.id])
    end
  end
end
