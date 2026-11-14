# frozen_string_literal: true

require 'rails_helper'

# Runs the real Rack::Attack rules in front of a stub app (the dummy app removes the middleware in tests).
# Over-limit requests get 503 with Retry-After, the app-wide choice documented in rack_attack.rb.
RSpec.describe 'Billing write throttles', :skip_host_setup do # rubocop:disable RSpec/DescribeClass
  let(:app) do
    Rack::Builder.new do
      use Rack::Attack
      run ->(_env) { [200, {}, ['ok']] }
    end
  end
  let(:store) { ActiveSupport::Cache::MemoryStore.new }

  around do |example|
    original = Rack::Attack.cache.store
    Rack::Attack.cache.store = store
    example.run
  ensure
    Rack::Attack.cache.store = original
  end

  def warden_for(id)
    id ? instance_double(Warden::Proxy, user: instance_double(BetterTogether::User, id:)) : nil
  end

  def call(path, method, ip: '203.0.113.9', user_id: nil)
    env = Rack::MockRequest.env_for(path, method:, 'REMOTE_ADDR' => ip)
    env['warden'] = warden_for(user_id)
    Rack::MockResponse.new(*app.call(env))
  end

  routes = {
    'checkout' => ['/en/billing/checkout', 'POST', 20, 10],
    'walk_up_sales' => ['/en/billing/walk_up_sale', 'POST', 20, 10],
    'sale_refunds' => ['/en/billing/sales/abc/refund', 'POST', 20, 10],
    'offline receive' => ['/en/billing/offline_payments/abc/receive', 'PATCH', 60, 30],
    'offline reject' => ['/en/billing/offline_payments/abc/reject', 'PATCH', 60, 30],
    'offline clear' => ['/en/billing/offline_payments/abc/clear', 'PATCH', 60, 30],
    'offline bounce' => ['/en/billing/offline_payments/abc/bounce', 'PATCH', 60, 30],
    'tax registration create' => ['/en/billing/tax_registrations', 'POST', 20, 10],
    'tax registration update' => ['/en/billing/tax_registrations/abc', 'PATCH', 20, 10],
    'agreement requirement create' => ['/en/billing/agreement_requirements', 'POST', 20, 10],
    'agreement requirement destroy' => ['/en/billing/agreement_requirements/abc', 'DELETE', 20, 10],
    'plan sync' => ['/en/billing/plans/abc/sync', 'POST', 10, 5]
  }

  routes.each do |label, (path, method, ip_limit, user_limit)|
    describe label do
      it "throttles the #{ip_limit + 1}th request from one address" do
        # A different person each time, so only the address limit can trip.
        ip_limit.times { |i| expect(call(path, method, user_id: "p#{i}").status).to eq(200), "request #{i + 1}" }

        blocked = call(path, method, user_id: 'p-last')
        expect(blocked.status).to eq(503)
        expect(blocked.headers['Retry-After'].to_i).to be_between(1, 60)
      end

      it "throttles the #{user_limit + 1}th request from one person across addresses" do
        user_limit.times { |i| expect(call(path, method, ip: "198.51.100.#{i + 1}", user_id: 'u1').status).to eq(200) }

        expect(call(path, method, ip: '198.51.100.99', user_id: 'u1').status).to eq(503)
        expect(call(path, method, ip: '198.51.100.99', user_id: 'u2').status).to eq(200)
      end
    end
  end

  it 'leaves GETs and unrelated billing pages alone' do
    25.times do
      expect(call('/en/billing/checkout/new', 'GET').status).to eq(200)
      expect(call('/en/billing/plans/abc/snapshot', 'GET').status).to eq(200)
    end
  end
end
