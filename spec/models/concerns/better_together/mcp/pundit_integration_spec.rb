# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::PunditIntegration do
  # Minimal tool class that includes the concern via ApplicationTool
  let(:tool_class) do
    Class.new(BetterTogether::Mcp::ApplicationTool) do
      description 'Test tool'
      def call
        'ok'
      end
    end
  end

  describe '#request' do
    context 'with HTTP headers from fast-mcp' do
      let(:headers) do
        {
          'host' => 'localhost',
          'user-agent' => 'test-agent',
          'cookie' => '_session_id=abc123'
        }
      end
      let(:tool) { tool_class.new(headers: headers) }

      it 'returns an ActionDispatch::Request' do
        expect(tool.send(:request)).to be_a(ActionDispatch::Request)
      end

      it 'populates request headers from @headers' do
        req = tool.send(:request)
        expect(req.env['HTTP_HOST']).to eq('localhost')
        expect(req.env['HTTP_COOKIE']).to eq('_session_id=abc123')
      end

      it 'is memoized — returns the same object on repeated calls' do
        first  = tool.send(:request)
        second = tool.send(:request)
        expect(first).to be(second)
      end
    end

    context 'with empty headers (anonymous / no session)' do
      let(:tool) { tool_class.new(headers: {}) }

      it 'does not raise' do
        expect { tool.send(:request) }.not_to raise_error
      end

      it 'returns an ActionDispatch::Request' do
        expect(tool.send(:request)).to be_a(ActionDispatch::Request)
      end
    end

    context 'without headers argument (nil @headers)' do
      let(:tool) { tool_class.new }

      it 'does not raise' do
        expect { tool.send(:request) }.not_to raise_error
      end

      it 'returns an ActionDispatch::Request' do
        expect(tool.send(:request)).to be_a(ActionDispatch::Request)
      end
    end
  end

  describe '#current_user' do
    let(:tool) { tool_class.new(headers: {}) }

    it 'returns nil for a tool call with no session (anonymous)' do
      expect(tool.send(:current_user)).to be_nil
    end
  end
end
