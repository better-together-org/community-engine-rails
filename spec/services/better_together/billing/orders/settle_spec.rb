# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Orders::Settle do
  include_context 'with orders fixtures'

  let(:order) { place_order }

  def pay(amount, status: 'succeeded', **attrs)
    create(:better_together_billing_payment, order:, amount_cents: amount, status:, currency: 'USD', **attrs)
  end

  it 'leaves an order with nothing paid as it is' do
    pay(4500, status: 'pending')

    expect { described_class.call(order) }.not_to(change { order.reload.status })
  end

  it 'marks an order paid, once, when payments cover the total' do
    pay(4500)

    described_class.call(order)

    expect(order.reload).to be_paid
    expect(order.paid_at).to be_present
    paid_at = order.paid_at
    described_class.call(order)
    expect(order.reload.paid_at).to eq(paid_at)
  end

  it 'marks an order partly paid, then paid when the rest arrives' do
    pay(1500)
    described_class.call(order)
    expect(order.reload).to be_partially_paid

    pay(3000)
    described_class.call(order)
    expect(order.reload).to be_paid
  end

  it 'adds up payments by different methods' do
    BetterTogether::Billing.register_builtin_processors!
    pay(3000, processor: 'fake')
    pay(1500, processor: 'cash')

    described_class.call(order)

    expect(order.reload).to be_paid
  end

  it 'lets a late payment pay an order that expired' do
    order.update!(status: 'expired')
    pay(4500)

    described_class.call(order)

    expect(order.reload).to be_paid
  end

  it 'marks the order refunded in part, then in full, as money goes back' do
    paid = pay(4500)
    described_class.call(order)

    create(:better_together_billing_refund, payment: paid, amount_cents: 1000)
    paid.update!(status: 'partially_refunded')
    described_class.call(order)
    expect(order.reload).to be_partially_refunded

    create(:better_together_billing_refund, payment: paid, amount_cents: 3500, idempotency_key: 'rest')
    paid.update!(status: 'refunded')
    described_class.call(order)
    expect(order.reload).to be_refunded
  end

  it 'settles an order that costs nothing' do
    free = create(:better_together_billing_plan, amount_cents: 0, currency: 'USD')
    zero = place_order(lines: [{ purchasable: free }])
    zero.update_columns(status: 'awaiting_payment', paid_at: nil) # rubocop:disable Rails/SkipsModelValidations

    described_class.call(zero)

    expect(zero.reload).to be_paid
  end

  it 'never moves a cancelled order' do
    order.update!(status: 'cancelled')
    pay(4500)

    expect { described_class.call(order) }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
