# frozen_string_literal: true

require 'rails_helper'

# The plan form asks the processor for option lists as a steward types, so the lookup
# endpoint has its own per-IP limit.
RSpec.describe 'Billing processor options throttle', :skip_host_setup do # rubocop:disable RSpec/DescribeClass
  let(:throttle) { Rack::Attack.throttles['billing/processor_options/ip'] }

  def request_for(path, method: 'GET', ip: '203.0.113.9')
    Rack::Attack::Request.new(Rack::MockRequest.env_for(path, method:, 'REMOTE_ADDR' => ip))
  end

  it 'is registered at 60 requests a minute' do
    expect(throttle).to be_present
    expect(throttle.limit).to eq(60)
    expect(throttle.period).to eq(60)
  end

  it 'counts lookup requests by IP' do
    expect(throttle.block.call(request_for('/en/billing/processor_options?kind=products'))).to eq('203.0.113.9')
  end

  it 'ignores other billing pages and other methods' do
    expect(throttle.block.call(request_for('/en/billing/plans'))).to be_nil
    expect(throttle.block.call(request_for('/en/billing/processor_options', method: 'POST'))).to be_nil
  end
end
