# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::PunditContext do
  describe '.from_request' do
    let(:user) { create(:user) }

    context 'with Warden session' do
      let(:warden) { instance_double(Warden::Proxy, user: user) }
      let(:request) do
        req = instance_double(Rack::Request, env: { 'warden' => warden })
        allow(req).to receive(:respond_to?).with(:env).and_return(true)
        req
      end

      it 'creates context with user from Warden session' do
        context = described_class.from_request(request)

        expect(context.user).to eq(user)
      end
    end

    context 'without Warden session' do
      let(:request) do
        req = instance_double(Rack::Request, env: {})
        allow(req).to receive(:respond_to?).with(:env).and_return(true)
        req
      end

      it 'creates context with nil user' do
        context = described_class.from_request(request)

        expect(context.user).to be_nil
      end
    end

    context 'when Warden returns nil user' do
      let(:warden) { instance_double(Warden::Proxy, user: nil) }
      let(:request) do
        req = instance_double(Rack::Request, env: { 'warden' => warden })
        allow(req).to receive(:respond_to?).with(:env).and_return(true)
        req
      end

      it 'creates context with nil user' do
        context = described_class.from_request(request)

        expect(context.user).to be_nil
      end
    end

    context 'when request does not support env' do
      let(:request) do
        req = instance_double(Rack::Request)
        allow(req).to receive(:respond_to?).with(:env).and_return(false)
        req
      end

      it 'creates context with nil user' do
        context = described_class.from_request(request)

        expect(context.user).to be_nil
      end
    end

    context 'security: ignores user_id from params' do
      let(:warden) { instance_double(Warden::Proxy, user: nil) }
      let(:request) do
        req = instance_double(Rack::Request,
                              env: { 'warden' => warden },
                              params: { 'user_id' => user.id })
        allow(req).to receive(:respond_to?).with(:env).and_return(true)
        req
      end

      it 'does NOT use user_id from params' do
        context = described_class.from_request(request)

        expect(context.user).to be_nil
      end
    end
  end

  describe '#initialize' do
    let(:user) { create(:user) }

    it 'stores user' do
      context = described_class.new(user: user)

      expect(context.user).to eq(user)
    end

    it 'accepts nil user' do
      context = described_class.new(user: nil)

      expect(context.user).to be_nil
    end
  end

  describe 'guest/authenticated predicates' do
    let(:user) { create(:user) }

    it 'is a guest when user is nil' do
      context = described_class.new(user: nil)

      expect(context.guest?).to be true
      expect(context.authenticated?).to be false
    end

    it 'is authenticated when user is present' do
      context = described_class.new(user: user)

      expect(context.guest?).to be false
      expect(context.authenticated?).to be true
    end
  end

  describe '#agent' do
    let(:user) { create(:user) }

    it 'returns person associated with user' do
      context = described_class.new(user: user)

      expect(context.agent).to eq(user.person)
    end

    context 'when user is nil' do
      it 'returns nil' do
        context = described_class.new(user: nil)

        expect(context.agent).to be_nil
      end
    end
  end

  describe '#permitted_to?' do
    let(:platform) { create(:platform, :as_host) }
    let(:user) { create(:user) }
    let(:context) { described_class.new(user: user) }

    before do
      configure_host_platform
    end

    it 'delegates to agent.permitted_to?' do
      allow(user.person).to receive(:permitted_to?).with('manage_platform', nil).and_return(true)

      result = context.permitted_to?('manage_platform')

      expect(result).to be true
      expect(user.person).to have_received(:permitted_to?).with('manage_platform', nil)
    end

    context 'when user is nil' do
      let(:context) { described_class.new(user: nil) }

      it 'returns false' do
        result = context.permitted_to?('manage_platform')

        expect(result).to be false
      end
    end
  end
end
