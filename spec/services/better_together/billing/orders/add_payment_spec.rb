# frozen_string_literal: true

require 'rails_helper'

# An order can be paid in parts, by any way of paying, one after another. A part-paid order is a normal state.
RSpec.describe BetterTogether::Billing::Orders::AddPayment do
  include_context 'with subscription fixtures'

  let(:refused) { described_class::Refused }
  let(:order) { place_order(payment_method: nil) }

  def add(method, amount = nil, key: SecureRandom.hex(4), to: order) # rubocop:disable Naming/MethodParameterName
    described_class.call(order: to, payment_method: method, amount_cents: amount, idempotency_key: key)
  end

  before { enable_offline('cheque', purposes: %w[subscription one_time]) }

  describe 'paying with credit' do
    it 'spends what is asked and leaves the order partly paid' do
      give_credit(4500)

      payment = add('store_credit', 2000)

      expect(payment).to have_attributes(processor: 'store_credit', status: 'succeeded', amount_cents: 2000)
      expect(order.reload).to be_partially_paid
      expect(order.balance_cents).to eq(2500)
      expect(credit.find_account(platform: host_platform, holder: buyer, currency: 'USD').balance_cents).to eq(2500)
    end

    it 'spends all it can when no amount is given, never more than the balance of the order' do
      give_credit(1200)
      expect(add('store_credit')).to have_attributes(amount_cents: 1200)

      give_credit(9000)
      expect(add('store_credit')).to have_attributes(amount_cents: 3300)
      expect(order.reload).to be_paid
    end

    it 'refuses more than the buyer can spend, and nothing when there is no credit' do
      give_credit(500)

      expect { add('store_credit', 501) }.to raise_error(refused, /not enough credit/)
      expect { add('store_credit', 500) }.not_to raise_error
      expect { add('store_credit') }.to raise_error(refused, /no credit/)
    end
  end

  describe 'completing an order in parts' do
    it 'is paid by credit and then cash, in either order' do
      give_credit(1500)
      add('store_credit', 1500)
      cash = add('cash')

      expect(cash).to have_attributes(amount_cents: 3000, status: 'pending')
      expect(order.reload).to be_partially_paid

      transition.receive(cash.offline_payment, by: steward)

      expect(order.reload).to be_paid
      expect(order.balance_cents).to eq(0)
    end

    it 'is paid by two manual methods and credit' do
      give_credit(500)
      add('store_credit', 500)
      add('cash', 2000)
      add('cheque')
      order.offline_payments.each { |offline| transition.receive(offline, by: steward) }
      order.offline_payments.select(&:cheque?).each { |cheque| transition.clear(cheque, by: steward) }

      expect(order.reload).to be_paid
      expect(order.payments.where(status: 'succeeded').pluck(:amount_cents)).to contain_exactly(500, 2000, 2000)
    end

    it 'refuses an amount that is nothing or more than is left' do
      expect { add('cash', 0) }.to raise_error(refused, /more than nothing/)
      expect { add('cash', 4501) }.to raise_error(refused, /more than is left/)
    end

    it 'refuses a way of paying that is not open for this kind of purchase' do
      host_platform.billing_processor_settings.find_by!(processor: 'cheque').update!(enabled: false)

      expect { add('cheque') }.to raise_error(refused)
      expect { add('unheard_of') }.to raise_error(refused, /not a way of paying/)
    end

    it 'refuses an order that is not waiting for payment' do
      order.update!(status: 'cancelled')

      expect { add('cash') }.to raise_error(refused, /not waiting/)
    end

    it 'is idempotent per key: a double click makes one payment' do
      give_credit(3000)

      first = add('store_credit', 1000, key: 'same')
      again = add('store_credit', 1000, key: 'same')

      expect(again).to eq(first)
      expect(order.payments.count).to eq(1)
      expect(credit.find_account(platform: host_platform, holder: buyer, currency: 'USD').balance_cents).to eq(2000)
    end
  end

  describe 'making room' do
    let!(:waiting_cash) { add('cash') }

    it 'shrinks a cash payment nobody has said they sent when credit takes part of the balance' do
      give_credit(2000)

      add('store_credit', 2000)

      expect(waiting_cash.reload.amount_cents).to eq(2500)
      expect(order.reload.balance_cents).to eq(2500)
    end

    it 'lets a waiting cash payment go when credit takes all of it' do
      give_credit(4500)

      add('store_credit', 4500)

      expect(waiting_cash.reload).to be_cancelled
      expect(waiting_cash.offline_payment).to be_cancelled
      expect(order.reload).to be_paid
    end

    it 'never touches a part the buyer has said they sent' do
      transition.claim(waiting_cash.offline_payment)
      give_credit(2000)

      expect { add('store_credit', 2000) }.to raise_error(refused, /already on its way/)
      expect(waiting_cash.reload.amount_cents).to eq(4500)
      expect(credit.find_account(platform: host_platform, holder: buyer, currency: 'USD').balance_cents).to eq(2000)
    end

    it 'never touches a cheque the seller has received' do
      other = place_order(payment_method: nil)
      cheque = add('cheque', to: other)
      transition.receive(cheque.offline_payment, by: steward)
      give_credit(1000)

      expect { add('store_credit', 1000, to: other) }.to raise_error(refused, /already on its way/)
    end
  end

  it 'opens a processor payment for a part, through the fake processor' do
    give_credit(1000)
    add('store_credit', 1000)

    payment = add('fake')

    expect(payment).to have_attributes(processor: 'fake', status: 'pending', amount_cents: 3500)
  end
end
