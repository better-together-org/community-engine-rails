# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::SearchQueryCaptureService do
  describe '#call' do
    let(:platform) { create(:better_together_platform, settings: settings) }
    let(:settings) { {} }

    around do |example|
      previous_platform = Current.platform
      Current.reset
      example.run
      Current.platform = previous_platform
    end

    it 'keeps normalized queries in full mode' do
      result = described_class.new(platform: platform).call("  Housing  Support \n")

      expect(result).to eq('Housing Support')
    end

    context 'when analytics are disabled' do
      let(:settings) { { search_query_analytics_enabled: false } }

      it 'returns nil' do
        result = described_class.new(platform: platform).call('housing support')

        expect(result).to be_nil
      end
    end

    context 'when analytics mode is hashed' do
      let(:settings) { { search_query_analytics_mode: 'hashed' } }

      it 'hashes the normalized query' do
        result = described_class.new(platform: platform).call(" Housing  Support \n")

        expect(result).to start_with('sha256:')
        expect(result).to eq("sha256:#{Digest::SHA256.hexdigest('housing support')}")
      end
    end

    it 'returns nil without explicit internal platform context' do
      result = described_class.new.call('housing support')

      expect(result).to be_nil
    end

    it 'returns nil for external platform context' do
      result = described_class.new(platform: create(:better_together_platform, external: true)).call('housing support')

      expect(result).to be_nil
    end
  end
end
