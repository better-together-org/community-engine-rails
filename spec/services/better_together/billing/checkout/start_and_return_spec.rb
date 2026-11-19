# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Starting and returning from a processor checkout' do # rubocop:disable RSpec/DescribeClass
  include_context 'with orders fixtures'

  let(:order) { place_order(payment_method: 'fake') }
  let(:payment) { order.payments.first }
  let(:urls) { { success_url: 'https://app.test/ok', cancel_url: 'https://app.test/cancel' } }

  def start = BetterTogether::Billing::Checkout::Start.call(order:, **urls)

  describe BetterTogether::Billing::Checkout::Start do
    it 'asks the adapter for a session for the pending payment, with a key of its own and the ids it will carry back' do
      url = start

      expect(url).to eq("https://fake.test/checkout/checkout:#{payment.id}")
      call = adapter.calls.find { |entry| entry.first == :create_checkout_session }
      expect(call.last).to include(idempotency_key: "checkout:#{payment.id}", order:, payment:,
                                   metadata: { bt_order_id: order.id, bt_payment_id: payment.id, bt_platform_id: host_platform.id })
    end

    it 'gives the processor the tax core worked out', :aggregate_failures do
      order.update_columns(tax_cents: 300, included_tax_cents: 100, prices_include_tax: false)
      start

      call = adapter.calls.find { |entry| entry.first == :create_checkout_session }
      expect(call.last).to include(tax_cents: 200, included_tax_cents: 100, prices_include_tax: false)
    end

    it 'keeps the session on the payment, so the buyer\'s return can be checked against it' do
      start

      expect(payment.reload.processor_session_reference).to eq("cs_checkout:#{payment.id}")
    end

    it 'sends a payment that needs the buyer to act to the processor\'s page for that instead' do
      payment.update!(failure_code: 'action_required')

      expect(start).to eq("https://fake.test/action/#{order.id}")
    end

    it 'has nothing to start for an order with no payment in flight, or one paid another way' do
      payment.update!(status: 'succeeded')

      expect { start }.to raise_error(described_class::Unavailable, /nothing to pay/)
    end

    it 'is unavailable when the processor is no longer configured for the platform' do
      payment
      allow(BetterTogether::Billing::Configuration).to receive(:context_for).and_return(nil)

      expect { start }.to raise_error(described_class::Unavailable, /not available/)
    end

    it 'never redirects anywhere but https, whatever the adapter returns' do
      payment
      ['http://fake.test/x', 'javascript:alert(1)', '//evil.test/x', 'not a url'].each do |bad|
        allow(adapter).to receive(:create_checkout_session)
          .and_return(BetterTogether::Billing::CheckoutSession.new(url: bad, reference: 'cs_x'))

        expect { start }.to raise_error(described_class::Unavailable, /usable address/)
      end
    end
  end

  describe BetterTogether::Billing::Checkout::Return do
    before { start }

    it 'syncs the session it sent this buyer to for this order, and reports the processor\'s status' do
      status = described_class.call(order:, session_id: payment.reload.processor_session_reference)

      expect(status).to eq('paid')
      expect(adapter.calls.last.first).to eq(:sync_checkout_session)
    end

    it 'believes no other session id: not another order\'s, not an invented one, not a blank one' do
      other = place_order(payment_method: 'fake', buyer: create(:better_together_person))
      BetterTogether::Billing::Checkout::Start.call(order: other, **urls)
      theirs = other.payments.first.processor_session_reference

      [theirs, 'cs_invented', '', nil].each do |session_id|
        expect { described_class.call(order:, session_id:) }.to raise_error(described_class::Unrecognised)
      end
      expect(adapter.calls.map(&:first)).not_to include(:sync_checkout_session)
    end
  end

  describe 'what an adapter returns' do
    it 'is a CheckoutSession and a RefundResult, plain values the rest of core can rely on' do
      context = BetterTogether::Billing::Configuration.context_for(host_platform, 'fake')

      session = adapter.create_checkout_session(context:, order:, payment:, success_url: 'https://a.test', cancel_url: 'https://b.test',
                                                idempotency_key: 'k', metadata: {})
      result = adapter.refund(context:, payment_reference: 'ch_1', amount_cents: 100, currency: 'USD', idempotency_key: 'r1', reason: nil)

      expect(session).to be_a(BetterTogether::Billing::CheckoutSession)
      expect(session.url).to start_with('https://')
      expect(result).to be_a(BetterTogether::Billing::RefundResult)
      expect(result).to have_attributes(reference: 're_r1', status: 'succeeded', amount_cents: 100)
    end

    it 'has no stored-value capability: store credit is a ledger inside core, not something a processor does' do
      expect(BetterTogether::Billing::ProcessorAdapter::CAPABILITIES).not_to include(:stored_value_credit)
      expect(BetterTogether::Billing::ProcessorAdapter.instance_methods).not_to include(:credit_balance, :reverse_credit)
    end
  end
end
