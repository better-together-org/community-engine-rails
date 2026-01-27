# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::PunditContext do
  describe '.from_request' do
    let(:user) { create(:user) }
    let(:request) { instance_double(Rack::Request, params: { 'user_id' => user.id }) }

    it 'creates context with user from request params' do
      context = described_class.from_request(request)

      expect(context.user).to eq(user)
    end

    context 'when user_id not in params' do
      let(:request) { instance_double(Rack::Request, params: {}) }

      it 'creates context with nil user' do
        context = described_class.from_request(request)

        expect(context.user).to be_nil
      end
    end

    context 'when user not found' do
      let(:request) { instance_double(Rack::Request, params: { 'user_id' => 'nonexistent' }) }

      it 'creates context with nil user' do
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
