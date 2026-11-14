# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::OriginGuard do
  # A stand-in for FastMcp::Transports::RackTransport's validate_origin surface, so the guard's own
  # accept/reject logic is tested apart from the gem's transport internals. extract_hostname mirrors
  # the gem's contract: a hostname for a URL or bare host, nil when none can be found.
  let(:transport_class) do
    Class.new do
      prepend BetterTogether::Mcp::OriginGuard

      def initialize
        @logger = Logger.new(nil)
      end

      def validate_origin(_request, _env)
        :gem_implementation
      end

      def extract_hostname(url)
        return nil if url.nil? || url.empty?

        URI.parse(url.match?(%r{^[a-zA-Z][a-zA-Z0-9+.-]*://}) ? url : "http://#{url}").host.presence
      end
    end
  end

  let(:transport) { transport_class.new }
  let(:request) { instance_double(Rack::Request, host: 'app.example.test') }

  before do
    allow(BetterTogether::Mcp::AllowedOrigins).to receive(:allowed?).and_return(false)
    allow(BetterTogether::Mcp::AllowedOrigins).to receive(:allowed?).with('app.example.test').and_return(true)
  end

  it 'replaces the gem implementation' do
    expect(transport.validate_origin(request, {})).not_to eq(:gem_implementation)
  end

  it 'accepts an Origin whose hostname is an allowed platform domain' do
    expect(transport.validate_origin(request, 'HTTP_ORIGIN' => 'https://app.example.test')).to be(true)
  end

  it 'ignores the port and scheme' do
    expect(transport.validate_origin(request, 'HTTP_ORIGIN' => 'http://app.example.test:3000')).to be(true)
  end

  it 'refuses a foreign Origin' do
    expect(transport.validate_origin(request, 'HTTP_ORIGIN' => 'https://evil.example')).to be(false)
  end

  it 'refuses the null Origin' do
    expect(transport.validate_origin(request, 'HTTP_ORIGIN' => 'null')).to be(false)
  end

  it 'falls back to the request host when there is no Origin, and accepts an allowed host' do
    expect(transport.validate_origin(request, {})).to be(true)
  end

  it 'refuses a request to an unknown Host with no Origin (DNS rebinding)' do
    rebound = instance_double(Rack::Request, host: 'rebound.evil.example')

    expect(transport.validate_origin(rebound, {})).to be(false)
  end

  it 'prefers the referer over the host when there is no Origin' do
    expect(transport.validate_origin(request, 'HTTP_REFERER' => 'https://evil.example/page')).to be(false)
  end

  it 'treats an empty Origin like a missing one' do
    expect(transport.validate_origin(request, 'HTTP_ORIGIN' => '')).to be(true)
  end

  it 'accepts a request with no hostname to check, as the gem does' do
    blank_host = instance_double(Rack::Request, host: '')

    expect(transport.validate_origin(blank_host, {})).to be(true)
  end

  context 'with the real fast-mcp transport' do
    let(:real_transport) do
      Class.new(FastMcp::Transports::RackTransport) { prepend BetterTogether::Mcp::OriginGuard }
           .new(->(_env) { [200, {}, []] }, instance_double(FastMcp::Server), logger: Logger.new(nil))
    end

    before do
      configure_host_platform
      host = BetterTogether::Platform.find_by!(host: true)
      BetterTogether::PlatformDomain.delete_all
      create(:better_together_platform_domain, platform: host, hostname: 'app.example.test')
      allow(BetterTogether::Mcp::AllowedOrigins).to receive(:allowed?).and_call_original
    end

    it 'accepts a platform domain Origin' do
      expect(real_transport.send(:validate_origin, request, 'HTTP_ORIGIN' => 'https://app.example.test')).to be(true)
    end

    it 'refuses a foreign Origin even though the transport was built with no static allowed origins' do
      expect(real_transport.send(:validate_origin, request, 'HTTP_ORIGIN' => 'https://evil.example')).to be(false)
    end
  end
end
