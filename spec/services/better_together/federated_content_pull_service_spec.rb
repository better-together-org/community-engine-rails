# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederatedContentPullService do
  describe '#call' do
    let(:connection) { create(:better_together_platform_connection, :active) }
    let(:resolution) do
      BetterTogether::Federation::Transport::Resolution.new(
        tier: :same_instance,
        adapter_class: adapter_class
      )
    end
    let(:adapter_class) { class_double(BetterTogether::Federation::Transport::DirectAdapter) }
    let(:result) do
      described_class::Result.new(
        connection:,
        seeds: [{ 'seed' => 'payload' }],
        next_cursor: 'cursor-2'
      )
    end

    it 'dispatches to the adapter returned by the resolver' do
      allow(BetterTogether::Federation::Transport::TransportResolver)
        .to receive(:call)
        .with(connection:)
        .and_return(resolution)
      allow(adapter_class)
        .to receive(:call)
        .with(connection:, cursor: 'cursor-1', limit: 25)
        .and_return(result)

      actual = described_class.call(connection:, cursor: 'cursor-1', limit: 25)

      expect(actual).to eq(result)
    end

    it 'supports remote http adapter resolutions without changing its public interface' do
      remote_adapter = class_double(BetterTogether::Federation::Transport::HttpAdapter)
      remote_resolution = BetterTogether::Federation::Transport::Resolution.new(
        tier: :remote_http,
        adapter_class: remote_adapter
      )

      allow(BetterTogether::Federation::Transport::TransportResolver).to receive(:call).and_return(remote_resolution)
      allow(remote_adapter).to receive(:call).and_return(result)

      expect(described_class.call(connection:)).to eq(result)
    end
  end
end
