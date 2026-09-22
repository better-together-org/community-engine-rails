# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::SseConcurrencyGuard do
  # A minimal double standing in for FastMcp::Transports::RackTransport's
  # relevant surface (@sse_clients + handle_sse_request), rather than
  # exercising the real gem's Rack-hijack machinery -- this isolates the
  # guard's own accept/reject logic from fast-mcp's SSE transport internals,
  # which are not something this repo owns or can safely drive in a request
  # spec (hijacking takes over the raw socket).
  let(:transport_class) do
    Class.new do
      prepend BetterTogether::Mcp::SseConcurrencyGuard

      attr_reader :super_called

      def initialize(client_count)
        @sse_clients = Array.new(client_count) { |i| [i, {}] }.to_h
        @super_called = false
      end

      def handle_sse_request(_request, _env)
        @super_called = true
        [200, {}, ['ok']]
      end
    end
  end

  def http_get_request
    instance_double(Rack::Request, get?: true)
  end

  before do
    # stub_const restores the original value automatically after each
    # example -- no manual teardown needed, and doing it via `around`
    # instead of `before` calls it outside rspec-mocks' per-example setup.
    stub_const("#{described_class}::MAX_GLOBAL_SSE_CONNECTIONS", 3)
  end

  it 'allows the request through when under the global connection cap' do
    transport = transport_class.new(2)

    status, = transport.handle_sse_request(http_get_request, {})

    expect(status).to eq(200)
    expect(transport.super_called).to be(true)
  end

  it 'rejects with 503 + Retry-After once at the global connection cap, without calling the real handler' do
    transport = transport_class.new(3)

    status, headers, = transport.handle_sse_request(http_get_request, {})

    expect(status).to eq(503)
    expect(headers['Retry-After']).to be_present
    expect(transport.super_called).to be(false)
  end

  it 'rejects once above the cap too (not just exactly at it)' do
    transport = transport_class.new(5)

    status, = transport.handle_sse_request(http_get_request, {})

    expect(status).to eq(503)
  end

  it 'does not apply the cap to non-GET requests (e.g. CORS preflight OPTIONS)' do
    transport = transport_class.new(3)
    options_request = instance_double(Rack::Request, get?: false)

    status, = transport.handle_sse_request(options_request, {})

    expect(status).to eq(200)
    expect(transport.super_called).to be(true)
  end
end
