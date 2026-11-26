# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Plans::Holdings do
  include_context 'with subscription fixtures'
  include_context 'with billing extras'

  def held = described_class.call(platform: host_platform, person: buyer)

  it 'holds nothing for a visitor or someone with no plan' do
    expect(described_class.call(platform: host_platform, person: nil)).to eq([])
    expect(held).to eq([])
  end

  it 'holds the plan of a live subscription' do
    start_subscription

    expect(held).to include(sub_plan.id)
  end

  it 'holds a plan with a live entitlement and stops when it is revoked' do
    entitlement = hold_plan!(sub_plan)
    expect(held).to eq([sub_plan.id])

    entitlement.update!(status: 'revoked')
    expect(held).to eq([])
  end
end
