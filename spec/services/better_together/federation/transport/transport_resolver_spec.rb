# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Federation::Transport::TransportResolver do
  describe '.call' do
    subject(:resolution) { described_class.call(connection:) }

    context 'when both platforms are locally hosted' do
      let(:source_platform) { create(:better_together_platform, locality: 'local') }
      let(:target_platform) { create(:better_together_platform, locality: 'local') }
      let(:connection) { create(:better_together_platform_connection, source_platform:, target_platform:) }

      it 'chooses the direct adapter' do
        expect(resolution.tier).to eq(:same_instance)
        expect(resolution.adapter_class).to eq(BetterTogether::Federation::Transport::DirectAdapter)
      end
    end

    context 'when either platform is external' do
      let(:source_platform) { create(:better_together_platform, :community_engine_peer, locality: 'remote') }
      let(:target_platform) { create(:better_together_platform, locality: 'local') }
      let(:connection) { create(:better_together_platform_connection, source_platform:, target_platform:) }

      it 'chooses the http adapter' do
        expect(resolution.tier).to eq(:remote_http)
        expect(resolution.adapter_class).to eq(BetterTogether::Federation::Transport::HttpAdapter)
      end
    end
  end
end
