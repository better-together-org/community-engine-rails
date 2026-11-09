# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Billing credit throttles' do # rubocop:disable RSpec/DescribeClass
  let(:throttles) { Rack::Attack.throttles }

  def request_for(path, method: 'GET', params: {})
    query = params.to_query
    Rack::Attack::Request.new(Rack::MockRequest.env_for("#{path}#{"?#{query}" if query.present?}", method:, 'REMOTE_ADDR' => '203.0.113.9'))
  end

  it 'limits person searches and credit grants, per address' do
    lookup = throttles.fetch('billing/credit_lookup/ip')
    grants = throttles.fetch('billing/credit_grants/ip')

    expect(lookup.limit).to eq(60)
    expect(lookup.block.call(request_for('/en/billing/credit_accounts/people', params: { search: 'someone' }))).to be_present
    expect(lookup.block.call(request_for('/en/billing/credit_accounts'))).to be_nil
    expect(lookup.block.call(request_for('/en/billing/credit_accounts/abc', params: { search: 'x' }))).to be_nil
    expect(grants.limit).to eq(20)
    expect(grants.block.call(request_for('/en/billing/credit_grants', method: 'POST'))).to be_present
    expect(grants.block.call(request_for('/en/billing/credit_grants'))).to be_nil
  end

  it 'limits redeeming a promotion code, per address' do
    throttle = throttles.fetch('billing/promotion_redemptions/ip')

    expect(throttle.limit).to eq(10)
    expect(throttle.block.call(request_for('/en/billing/promotion_redemptions', method: 'POST'))).to be_present
    expect(throttle.block.call(request_for('/en/billing/promotion_redemptions'))).to be_nil
  end

  it 'limits adding a payment to an order, per address' do
    throttle = throttles.fetch('billing/order_payments/ip')

    expect(throttle.limit).to eq(20)
    expect(throttle.block.call(request_for('/en/billing/orders/abc/payments', method: 'POST'))).to be_present
    expect(throttle.block.call(request_for('/en/billing/orders/abc/payments'))).to be_nil
  end
end
