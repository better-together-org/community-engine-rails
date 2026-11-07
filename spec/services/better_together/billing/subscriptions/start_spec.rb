# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Subscriptions::Start do
  include_context 'with subscription fixtures'

  let(:term) { start_subscription }
  let(:subscription) { term.pay_subscription }

  it 'starts a Pay subscription from a paid first order, running to the end of the first period' do
    expect(subscription).to be_a(Pay::Local::Subscription)
    expect(subscription).to have_attributes(status: 'active', processor_plan: sub_plan.identifier, current_period_start: start_time,
                                            current_period_end: Time.utc(2027, 2, 28, 15), ends_at: nil, platform_id: host_platform.id)
    expect(subscription.customer.owner).to eq(buyer)
    expect(subscription).to be_active
  end

  it 'makes the terms: the plan, the method, the price it was sold at and the anchor' do
    expect(term).to have_attributes(plan: sub_plan, payment_method: 'cash', unit_amount_cents: 3000, currency: 'USD', anchor_at: start_time,
                                    anchor_sequence: 0, grace_ends_at: nil, platform_id: host_platform.id, payer: buyer)
    expect(term).to be_local
  end

  it 'records the first period as paid by this order, and links the order to the subscription' do
    period = term.periods.sole

    expect(period).to have_attributes(sequence: 0, starts_at: start_time, ends_at: Time.utc(2027, 2, 28, 15), status: 'paid')
    expect(period.order).to have_attributes(subject: term, pay_subscription: subscription)
  end

  it 'is visible to Pay\'s own scopes' do
    term

    expect(Pay::Subscription.active).to include(subscription)
    expect(Pay::Subscription.past_due).not_to include(subscription)
  end

  it 'starts on the day the money really arrived when the seller recorded it' do
    travel_to(start_time) do
      order = place_order(purpose: 'subscription', payment_method: 'cash', lines: [{ purchasable: sub_plan }])
      pay_manually(order, received_on: Date.new(2027, 1, 29))
      follow_up
      expect(order.reload.subject.anchor_at).to be_within(1.second).of(Time.utc(2027, 1, 29).end_of_day)
    end
  end

  it 'also starts from store credit' do
    expect(start_subscription(method: 'store_credit').payment_method).to eq('store_credit')
  end

  it 'is done once however often it runs' do
    term
    order = term.periods.sole.order

    expect { described_class.call(order:) }.not_to change(Pay::Subscription, :count)
    expect(described_class.call(order:)).to eq(term)
  end

  it 'only starts a subscription for a recurring plan sold by the platform and paid by Community Engine' do
    once = create(:better_together_billing_plan, :one_time, processor: nil, processor_price_id: nil, accepted_payment_methods: %w[cash])
    one_off = travel_to(start_time) do
      order = place_order(purpose: 'one_time', payment_method: 'cash', lines: [{ purchasable: once }])
      pay_manually(order)
    end

    expect(described_class.startable?(one_off)).to be(false)
    expect(described_class.call(order: one_off)).to be_nil
  end
end
