# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Federation::Transport::TransportResolver do
  describe '.call' do
    subject(:resolution) { described_class.call(connection:) }

    context 'when both platforms are locally hosted' do
      let(:source_platform) { create(:better_together_platform, external: false) }
      let(:target_platform) { create(:better_together_platform, external: false) }
      let(:connection) { create(:better_together_platform_connection, source_platform:, target_platform:) }

      it 'chooses the direct adapter' do
        expect(resolution.tier).to eq(:same_instance)
        expect(resolution.adapter_class).to eq(BetterTogether::Federation::Transport::DirectAdapter)
      end
    end

    context 'when either platform is external' do
      let(:source_platform) { create(:better_together_platform, :community_engine_peer, external: true) }
      let(:target_platform) { create(:better_together_platform, external: false) }
      let(:connection) { create(:better_together_platform_connection, source_platform:, target_platform:) }

      it 'chooses the http adapter' do
        expect(resolution.tier).to eq(:remote_http)
        expect(resolution.adapter_class).to eq(BetterTogether::Federation::Transport::HttpAdapter)
      end
    end
  end
end
