# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Subscription do
  subject(:subscription) { build('better_together/billing/subscription') }

  it 'is valid with the factory defaults' do
    expect(subscription).to be_valid
  end

  it 'identifies activeish statuses' do
    expect(subscription.activeish?).to be(true)

    subscription.pay_subscription.status = 'canceled'

    expect(subscription.activeish?).to be(false)
  end

  it 'delegates status to pay_subscription' do
    expect(subscription.status).to eq(subscription.pay_subscription.status)
  end

  it 'exposes the processor from the pay customer' do
    expect(subscription.processor).to eq('stripe')
  end

  it 'persists portal access failures in metadata' do
    subscription = create('better_together/billing/subscription')

    subscription.record_portal_access_failure!(message: 'Stripe portal outage')

    expect(subscription.reload.portal_access_issue?).to be(true)
    expect(subscription.last_portal_error_message).to eq('Stripe portal outage')
  end
end
