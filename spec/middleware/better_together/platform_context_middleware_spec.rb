# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformContextMiddleware do
  # Build a capturing inner app so we can observe Current state *inside* the middleware stack.
  def capturing_app
    captured = {}
    app = lambda do |_env|
      captured[:platform]        = Current.platform
      captured[:platform_domain] = Current.platform_domain
      [200, { 'Content-Type' => 'text/plain' }, ['ok']]
    end
    [described_class.new(app), captured]
  end

  def call_with_host(host)
    middleware, captured = capturing_app
    env = Rack::MockRequest.env_for("http://#{host}/")
    [middleware.call(env), captured]
  end

  describe '#call' do
    context 'when the request host matches a registered PlatformDomain' do
      let!(:platform) { create(:better_together_platform) }
      let!(:domain) do
        create(:better_together_platform_domain, hostname: 'bt-test.example', platform:)
      end

      it 'sets Current.platform to the matched platform' do
        _response, captured = call_with_host('bt-test.example')
        expect(captured[:platform]).to eq(platform)
      end

      it 'sets Current.platform_domain to the matched domain' do
        _response, captured = call_with_host('bt-test.example')
        expect(captured[:platform_domain]).to eq(domain)
      end
    end

    context 'when the request host does not match any PlatformDomain' do
      it 'falls back to the host platform' do
        host_platform = configure_host_platform
        _response, captured = call_with_host('unknown-host.test')
        expect(captured[:platform]).to eq(host_platform)
      end

      it 'sets Current.platform_domain to nil' do
        configure_host_platform
        _response, captured = call_with_host('unknown-host.test')
        expect(captured[:platform_domain]).to be_nil
      end
    end

    context 'when fail-closed is enabled and several platforms exist' do
      around do |example|
        previous = BetterTogether.fail_closed_unknown_hosts
        BetterTogether.fail_closed_unknown_hosts = true
        example.run
      ensure
        BetterTogether.fail_closed_unknown_hosts = previous
      end

      before do
        configure_host_platform
        create(:better_together_platform)
        Rails.cache.delete('better_together/single_platform')
      end

      after { Rails.cache.delete('better_together/single_platform') }

      it 'returns 404 for an unknown host' do
        response, captured = call_with_host('unknown-host.test')
        expect(response.first).to eq(404)
        expect(captured).to be_empty
      end

      it 'still serves health checks' do
        middleware, captured = capturing_app
        status, = middleware.call(Rack::MockRequest.env_for('http://unknown-host.test/up'))
        expect(status).to eq(200)
        expect(captured[:platform]).to be_present
      end
    end

    context 'when no domain or host platform exists' do
      it 'sets Current.platform to nil' do
        # better_together_platforms is in ESSENTIAL_TABLES so host platforms persist
        # across parallel workers. Stub both resolution paths to simulate a bare DB.
        allow(BetterTogether::PlatformDomain).to receive(:resolve).and_return(nil)
        allow(Rails.cache).to receive(:fetch)
          .with('better_together/host_platform_id', expires_in: 5.minutes)
          .and_return(nil)
        _response, captured = call_with_host('unknown-host.test')
        expect(captured[:platform]).to be_nil
      end
    end

    it 'resets Current after the response' do
      configure_host_platform
      middleware, = capturing_app
      middleware.call(Rack::MockRequest.env_for('http://www.example.com/'))
      expect(Current.platform).to be_nil
      expect(Current.platform_domain).to be_nil
    end

    it 'resets Current even when the inner app raises' do
      configure_host_platform
      raise_app = described_class.new(->(_env) { raise 'inner app error' })
      expect { raise_app.call(Rack::MockRequest.env_for('http://www.example.com/')) }
        .to raise_error(RuntimeError, 'inner app error')
      expect(Current.platform).to be_nil
    end

    it 'passes the request through to the inner app' do
      middleware, = capturing_app
      status, _headers, _body = middleware.call(Rack::MockRequest.env_for('http://www.example.com/'))
      expect(status).to eq(200)
    end
  end
end
