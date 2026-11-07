# frozen_string_literal: true

require 'rails_helper'

# Starting a payment creates a checkout session at the processor, so it has its own per-IP limit.
RSpec.describe 'Billing order pay throttle', :skip_host_setup do # rubocop:disable RSpec/DescribeClass
  let(:throttle) { Rack::Attack.throttles['billing/order_pay/ip'] }

  def request_for(path, method: 'POST', ip: '203.0.113.9')
    Rack::Attack::Request.new(Rack::MockRequest.env_for(path, method:, 'REMOTE_ADDR' => ip))
  end

  it 'is registered at 20 requests a minute' do
    expect([throttle.limit, throttle.period]).to eq([20, 60])
  end

  it 'counts pay requests by IP' do
    expect(throttle.block.call(request_for('/en/billing/orders/abc/pay'))).to eq('203.0.113.9')
  end

  it 'ignores the return page, other pages and GET' do
    expect(throttle.block.call(request_for('/en/billing/orders/abc/checkout_return', method: 'GET'))).to be_nil
    expect(throttle.block.call(request_for('/en/billing/orders/abc/pay', method: 'GET'))).to be_nil
    expect(throttle.block.call(request_for('/en/billing/orders/abc'))).to be_nil
  end
end
