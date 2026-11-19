# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Checkout::Start, '#call with the processor and its tax' do
  include_context 'with orders fixtures'
  include_context 'with billing notifications'

  let(:order) { place_order(payment_method: 'fake') }
  let(:payment) { order.payments.first }
  let(:urls) { { success_url: 'https://app.test/ok', cancel_url: 'https://app.test/cancel' } }

  before do
    steward
    order.update_columns(tax_cents: 300, included_tax_cents: 100, prices_include_tax: false)
  end

  def session(tax_cents) = BetterTogether::Billing::CheckoutSession.new(url: 'https://fake.test/x', reference: 'cs_x', tax_cents:)

  it 'still starts a checkout with an adapter that does not name the tax keywords' do
    old_style = Class.new(adapter.class) do
      def create_checkout_session(context:, order:, payment:, success_url:, cancel_url:, idempotency_key:, metadata:) # rubocop:disable Lint/UnusedMethodArgument, Metrics/ParameterLists
        BetterTogether::Billing::CheckoutSession.new(url: 'https://fake.test/old', reference: "cs_#{idempotency_key}")
      end
    end.new
    allow(BetterTogether::Billing).to receive(:processor_adapter).with('fake').and_return(old_style)

    expect(described_class.call(order:, **urls)).to eq('https://fake.test/old')
  end

  it 'tells the operators once when the processor reports a different tax than core worked out' do
    allow(adapter).to receive(:create_checkout_session).and_return(session(999))

    deliver_now { 2.times { described_class.call(order:, **urls) } }

    expect(kinds_for(steward).grep(/mismatch/)).to eq(['payment_amount_mismatch'])
  end

  it 'says nothing when the processor reports the same tax, or none' do
    allow(adapter).to receive(:create_checkout_session).and_return(session(200), session(nil))

    deliver_now { 2.times { described_class.call(order:, **urls) } }

    expect(kinds_for(steward).grep(/mismatch/)).to be_empty
  end
end
