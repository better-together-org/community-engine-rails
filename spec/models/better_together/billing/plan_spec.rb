# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Plan do
  subject(:plan) { build('better_together/billing/plan') }

  it 'is valid with the factory defaults' do
    expect(plan).to be_valid
  end

  it 'requires a supported billing interval' do
    plan.billing_interval = 'week'

    expect(plan).not_to be_valid
    expect(plan.errors[:billing_interval]).to be_present
  end

  it 'reports recurring plans correctly' do
    expect(plan.recurring?).to be(true)

    plan.billing_interval = 'one_time'

    expect(plan.recurring?).to be(false)
  end
end
