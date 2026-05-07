# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Subscription do
  subject(:subscription) { build('better_together/billing/subscription') }

  it 'is valid with the factory defaults' do
    expect(subscription).to be_valid
  end

  it 'requires a supported processor' do
    subscription.processor = 'paypal'

    expect(subscription).not_to be_valid
    expect(subscription.errors[:processor]).to be_present
  end

  it 'identifies activeish statuses' do
    expect(subscription.activeish?).to be(true)

    subscription.status = 'canceled'

    expect(subscription.activeish?).to be(false)
  end

  it 'exposes the beneficiary community for compatibility' do
    expect(subscription.community).to eq(subscription.beneficiary)
  end
end
