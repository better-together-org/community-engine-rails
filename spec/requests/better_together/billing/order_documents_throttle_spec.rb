# frozen_string_literal: true

require 'rails_helper'

# Making the documents again renders and stores PDFs, so it has its own per-IP limit.
RSpec.describe 'Billing order documents throttle', :skip_host_setup do # rubocop:disable RSpec/DescribeClass
  let(:throttle) { Rack::Attack.throttles['billing/order_documents/ip'] }

  def request_for(path, method: 'POST', ip: '203.0.113.9')
    Rack::Attack::Request.new(Rack::MockRequest.env_for(path, method:, 'REMOTE_ADDR' => ip))
  end

  it 'is registered at 10 requests a minute' do
    expect([throttle.limit, throttle.period]).to eq([10, 60])
  end

  it 'counts regenerate requests on orders and sales by IP', :aggregate_failures do
    expect(throttle.block.call(request_for('/en/billing/orders/abc/documents'))).to eq('203.0.113.9')
    expect(throttle.block.call(request_for('/en/billing/sales/abc/documents'))).to eq('203.0.113.9')
  end

  it 'ignores other pages and GET', :aggregate_failures do
    expect(throttle.block.call(request_for('/en/billing/orders/abc/documents', method: 'GET'))).to be_nil
    expect(throttle.block.call(request_for('/en/billing/orders/abc'))).to be_nil
  end
end
