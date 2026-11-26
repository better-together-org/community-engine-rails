# frozen_string_literal: true

require 'rails_helper'

# A subscription started in parts, renewed by the way the buyer chose, with renewal invoices that credit can part pay.
RSpec.describe 'Subscriptions paid in parts' do # rubocop:disable RSpec/DescribeClass
  include_context 'with entitlement fixtures'

  let(:billing) { BetterTogether::Billing }

  # Places the first order in parts, pays the cash part and follows up.
  def start_in_parts(credit_cents: 1000, renewal: nil, at: start_time)
    travel_to(at) do
      give_credit(credit_cents)
      order = place_order(buyer:, purpose: 'subscription', payment_method: nil, line_items: [{ purchasable: sub_plan }],
                          renewal_payment_method: renewal,
                          payments: [{ payment_method: 'store_credit', amount_cents: credit_cents }, { payment_method: 'cash' }])
      order.offline_payments.each { |offline| transition.receive(offline, by: steward) }
      follow_up
      order.reload
    end
  end

  it 'does not start until the order is paid in full' do
    travel_to(start_time) do
      give_credit(1000)
      order = place_order(buyer:, purpose: 'subscription', payment_method: nil, line_items: [{ purchasable: sub_plan }],
                          payments: [{ payment_method: 'store_credit', amount_cents: 1000 }, { payment_method: 'cash' }])
      follow_up

      expect(order.reload).to be_partially_paid
      expect(order.subject).to be_nil
      expect(Pay::Subscription.count).to eq(0)
    end
  end

  it 'starts once the last part is received, renewing by the way that paid the larger share' do
    order = start_in_parts

    term = order.subject
    expect(order).to be_paid
    expect(term).to have_attributes(payment_method: 'cash', unit_amount_cents: 3000)
  end

  it 'renews by the way the buyer chose, whatever paid the order' do
    term = start_in_parts(renewal: 'store_credit').subject

    expect(term.payment_method).to eq('store_credit')
  end

  it 'falls back to store credit when credit was the only thing that paid' do
    term = start_in_parts(credit_cents: 3000).subject

    expect(term.payment_method).to eq('store_credit')
  end

  it 'leaves a subscription whose first part went through a processor to the processor' do
    order = place_order(purpose: 'subscription', payment_method: 'cash', line_items: [{ purchasable: sub_plan }])
    pay_manually(order)
    order.payments.first.update!(processor: 'fake')

    expect(billing::Subscriptions::Start.startable?(order.reload)).to be(false)
  end

  describe 'a renewal invoice paid partly from credit' do
    let(:term) { start_in_parts(credit_cents: 1000, renewal: 'store_credit').subject }
    let(:inside_lead) { Time.utc(2027, 2, 20, 15) }

    it 'spends what credit has, stays partly paid, and tells the payer what is short' do
      term
      give_credit(1200)
      clear_notices
      period = nil
      deliver_now { period = generate_renewal(term, at: inside_lead) }

      order = period.reload.order
      expect(order).to be_partially_paid
      expect(order.payments.sole).to have_attributes(processor: 'store_credit', amount_cents: 1200)
      expect(order.balance_cents).to eq(1800)
      expect(period.reload).not_to be_paid
      expect(kinds_for(buyer)).to include('renewal_credit_insufficient')
    end

    it 'tops up on a later attempt without paying twice, and the period moves on only when the whole is paid' do
      term
      give_credit(1200)
      period = generate_renewal(term, at: inside_lead)
      give_credit(5000)
      travel_to(inside_lead + 1.day) { follow_up { billing::Subscriptions::PayWithCredit.call(period: period.reload) } }

      expect(period.reload.order).to be_paid
      expect(period.order.payments.sum(&:amount_cents)).to eq(3000)
      expect(term.reload.pay_subscription.current_period_end).to eq(Time.utc(2027, 3, 31, 15))
    end

    it 'lets the payer add cash for the rest from the invoice, and does not take that part over' do
      term
      give_credit(1200)
      period = generate_renewal(term, at: inside_lead)
      order = period.reload.order
      cash = billing::Orders::AddPayment.call(order:, payment_method: 'cash', idempotency_key: 'rest')

      give_credit(5000)
      billing::Subscriptions::PayWithCredit.call(period: period.reload)

      expect(cash.reload).to have_attributes(amount_cents: 1800, status: 'pending')
      expect(order.reload).to be_partially_paid
    end

    it 'does not count a part payment as overdue-proof: the subscription still goes past due after the period ends' do
      term
      give_credit(1200)
      period = generate_renewal(term, at: inside_lead)

      advance(term, at: Time.utc(2027, 3, 1, 15))

      expect(period.reload.order).to be_partially_paid
      expect(term.reload.pay_subscription.status).to eq('past_due')
    end
  end

  describe 'entitlements' do
    before { role_grant }

    it 'are not given until the order is paid in full, and are given once' do
      travel_to(start_time) do
        give_credit(1000)
        order = place_order(buyer:, purpose: 'subscription', payment_method: nil, line_items: [{ purchasable: sub_plan }],
                            payments: [{ payment_method: 'store_credit', amount_cents: 1000 }, { payment_method: 'cash' }])
        follow_up
        expect(platform_membership(buyer)).to be_nil
        expect(host_platform.billing_entitlements.count).to eq(0)

        order.offline_payments.each { |offline| transition.receive(offline, by: steward) }
        follow_up
        2.times { follow_up }

        expect(platform_membership(buyer)).to be_present
        expect(host_platform.billing_entitlements.count).to eq(1)
      end
    end

    it 'are not given when one part of an unpaid order is refunded' do
      travel_to(start_time) do
        give_credit(1000)
        order = place_order(buyer:, purpose: 'subscription', payment_method: nil, line_items: [{ purchasable: sub_plan }],
                            payments: [{ payment_method: 'store_credit', amount_cents: 1000 }, { payment_method: 'cash' }])
        billing::Orders::ReturnPayments.call(order:, actor: steward)
        follow_up

        expect(host_platform.billing_entitlements.count).to eq(0)
        expect(order.reload).to be_awaiting_payment
      end
    end
  end
end
