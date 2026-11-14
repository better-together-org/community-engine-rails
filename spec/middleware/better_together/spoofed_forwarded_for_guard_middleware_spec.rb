# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SpoofedForwardedForGuardMiddleware do
  # RemoteIp only raises IpSpoofAttackError when something downstream forces
  # its lazily-memoized #remote_ip to resolve (in production, Rails::Rack::Logger
  # does this on every request). Mirror that here instead of relying on
  # RemoteIp#call itself raising, since it doesn't -- it defers the raise.
  let(:inner_app) do
    lambda do |env|
      ActionDispatch::Request.new(env).remote_ip.to_s
      [200, { 'Content-Type' => 'text/plain' }, ['ok']]
    end
  end

  def build_stack
    described_class.new(ActionDispatch::RemoteIp.new(inner_app))
  end

  describe '#call' do
    context 'when HTTP_CLIENT_IP and X-Forwarded-For disagree (the WordPress-bot pattern)' do
      let(:env) do
        Rack::MockRequest.env_for(
          '/',
          'HTTP_CLIENT_IP' => '127.0.0.1',
          'HTTP_X_FORWARDED_FOR' => '195.178.110.101'
        )
      end

      it 'returns a blocked response instead of letting IpSpoofAttackError propagate' do
        status, = build_stack.call(env)
        expect(status).to eq(503)
      end

      it 'logs a warning naming the guard' do
        expect(Rails.logger).to receive(:warn).with(/spoofed_forwarded_for_guard/)
        build_stack.call(env)
      end
    end

    context 'when HTTP_CLIENT_IP and X-Forwarded-For agree (legitimate double-header proxy setup)' do
      let(:env) do
        Rack::MockRequest.env_for(
          '/',
          'HTTP_CLIENT_IP' => '203.0.113.5',
          'HTTP_X_FORWARDED_FOR' => '203.0.113.5'
        )
      end

      it 'passes the request through untouched' do
        status, _headers, body = build_stack.call(env)
        expect(status).to eq(200)
        expect(body).to eq(['ok'])
      end
    end

    context 'when only X-Forwarded-For is set (normal single-header proxy chain)' do
      let(:env) do
        Rack::MockRequest.env_for('/', 'HTTP_X_FORWARDED_FOR' => '203.0.113.5, 10.45.20.1')
      end

      it 'passes the request through untouched' do
        status, = build_stack.call(env)
        expect(status).to eq(200)
      end
    end

    it 'does not swallow unrelated errors from the rest of the stack' do
      raising_app = described_class.new(->(_env) { raise 'inner app error' })
      expect { raising_app.call(Rack::MockRequest.env_for('/')) }
        .to raise_error(RuntimeError, 'inner app error')
    end
  end
end
