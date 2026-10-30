# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Payment services' do # rubocop:disable RSpec/DescribeClass
  include_context 'with orders fixtures'

  let(:order) { place_order }

  def create_payment(**attrs)
    BetterTogether::Billing::Payments::Create.call(order:, processor: 'fake', amount_cents: 4500, idempotency_key: 'req-1', **attrs)
  end

  describe BetterTogether::Billing::Payments::Create do
    it 'starts a pending payment in the order\'s currency, on its platform' do
      payment = create_payment

      expect(payment).to have_attributes(status: 'pending', amount_cents: 4500, currency: 'USD', platform_id: host_platform.id,
                                         processor: 'fake')
    end

    it 'finds the payment it already made when the request is repeated' do
      first = create_payment

      expect { expect(create_payment).to eq(first) }.not_to change(BetterTogether::Billing::Payment, :count)
    end

    it 'refuses more than is owed, counting other payments in flight' do
      create_payment(amount_cents: 3000, idempotency_key: 'a')

      expect { create_payment(amount_cents: 2000, idempotency_key: 'b') }.to raise_error(described_class::Refused, /more than is owed/)
      expect(create_payment(amount_cents: 1500, idempotency_key: 'c')).to be_persisted
    end

    it 'refuses an order that is not waiting for payment' do
      order.update!(status: 'cancelled')

      expect { create_payment }.to raise_error(described_class::Refused, /not waiting/)
    end

    it 'accepts a late payment for an order that expired' do
      order.update!(status: 'expired')

      expect(create_payment).to be_persisted
    end

    it 'refuses a method that is not installed' do
      expect { create_payment(processor: 'bitcoin') }.to raise_error(described_class::Refused)
    end
  end

  describe BetterTogether::Billing::Payments::Succeed do
    let(:payment) { BetterTogether::Billing::Payments::Create.call(order:, processor: 'fake', amount_cents: 4500, idempotency_key: 'req') }

    it 'marks the payment received, keeps the processor\'s reference and pays the order' do
      described_class.call(payment, reference: 'ch_123')

      expect(payment.reload).to have_attributes(status: 'succeeded', processor_reference: 'ch_123')
      expect(payment.paid_at).to be_present
      expect(order.reload).to be_paid
    end

    it 'is safe to repeat' do
      described_class.call(payment, reference: 'ch_123')
      paid_at = payment.reload.paid_at

      expect { described_class.call(payment, reference: 'ch_999') }.not_to(change do
        payment.reload.attributes.slice('paid_at', 'processor_reference')
      end)
      expect(payment.paid_at).to eq(paid_at)
    end

    it 'pays an order in parts' do
      part = BetterTogether::Billing::Payments::Create.call(order:, processor: 'fake', amount_cents: 1500, idempotency_key: 'part')
      described_class.call(part)

      expect(order.reload).to be_partially_paid
    end
  end

  describe BetterTogether::Billing::Payments::Fail do
    it 'marks a pending payment failed and leaves the order open to try another way' do
      payment = BetterTogether::Billing::Payments::Create.call(order:, processor: 'fake', amount_cents: 4500, idempotency_key: 'req')

      described_class.call(payment)

      expect(payment.reload).to have_attributes(status: 'failed')
      expect(payment.failed_at).to be_present
      expect(order.reload).to be_awaiting_payment
    end

    it 'does not undo a payment that already succeeded' do
      payment = create(:better_together_billing_payment, order:, status: 'succeeded', amount_cents: 4500)

      described_class.call(payment)

      expect(payment.reload).to be_succeeded
    end
  end
end
