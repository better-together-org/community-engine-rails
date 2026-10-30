# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Cancelling and expiring orders' do # rubocop:disable RSpec/DescribeClass
  include_context 'with orders fixtures'

  let(:order) { place_order }

  describe BetterTogether::Billing::Orders::Cancel do
    it 'cancels an unpaid order, what was waiting to be paid, and gives back what it held' do
      waiting = create(:better_together_billing_payment, order:, amount_cents: 4500)
      allow(BetterTogether::Billing::Orders::Release).to receive(:call)

      described_class.call(order)

      expect(order.reload).to be_cancelled
      expect(order.cancelled_at).to be_present
      expect(waiting.reload).to be_cancelled
      expect(BetterTogether::Billing::Orders::Release).to have_received(:call).with(order)
    end

    it 'refuses an order that has money against it' do
      create(:better_together_billing_payment, order:, amount_cents: 4500, status: 'succeeded')

      expect { described_class.call(order) }.to raise_error(described_class::Refused, /unpaid/)
      expect(order.reload).not_to be_cancelled
    end

    it 'refuses an order that is already final' do
      order.update!(status: 'cancelled')

      expect { described_class.call(order) }.to raise_error(described_class::Refused)
    end
  end

  describe BetterTogether::Billing::Orders::Release do
    it 'gives back what each line held, by the quantity ordered' do
      two = place_order(lines: [{ purchasable: plan, quantity: 2 }])
      held = []
      two.lines.each do |line|
        held_plan = instance_double(BetterTogether::Billing::Plan)
        allow(held_plan).to receive(:release!) { |quantity:| held << quantity }
        allow(line).to receive(:purchasable).and_return(held_plan)
      end

      described_class.call(two)

      expect(held).to eq([2])
    end
  end

  describe BetterTogether::Billing::Orders::Expire do
    it 'lets an order whose hold ran out lapse, cancelling what was waiting' do
      order.update!(expires_at: 1.minute.ago)
      waiting = create(:better_together_billing_payment, order:, amount_cents: 4500)

      expect(described_class.call(order)).to be(true)

      expect(order.reload).to be_expired
      expect(waiting.reload).to be_cancelled
    end

    it 'leaves an order that is not due yet, and one that is not waiting' do
      expect(described_class.call(order)).to be(false)
      expect(order.reload).to be_awaiting_payment

      paid = place_order
      paid.update!(status: 'paid', expires_at: 1.hour.ago)
      expect(described_class.call(paid)).to be(false)
    end

    it 'leaves an order that was paid while it waited for the lock' do
      order.update!(expires_at: 1.minute.ago)
      stale = BetterTogether::Billing::Order.find(order.id)
      create(:better_together_billing_payment, order:, amount_cents: 4500, status: 'succeeded')
      BetterTogether::Billing::Orders::Settle.call(order)

      expect(described_class.call(stale)).to be(false)
      expect(order.reload).to be_paid
    end

    it 'can still be paid afterwards by a late payment' do
      order.update!(expires_at: 1.minute.ago)
      described_class.call(order)
      late = create(:better_together_billing_payment, order:, amount_cents: 4500, status: 'succeeded')

      BetterTogether::Billing::Orders::Settle.call(late.order)

      expect(order.reload).to be_paid
    end
  end
end
