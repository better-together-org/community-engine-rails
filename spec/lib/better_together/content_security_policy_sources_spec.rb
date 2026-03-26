# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurityPolicySources do
  describe '.asset_host_source' do
    it 'returns nil when ASSET_HOST is blank' do
      expect(described_class.asset_host_source(nil)).to be_nil
      expect(described_class.asset_host_source('')).to be_nil
    end

    it 'normalizes a full asset host URL to its origin' do
      expect(described_class.asset_host_source('https://cdn-assets.newfoundlandlabrador.online/assets'))
        .to eq('https://cdn-assets.newfoundlandlabrador.online')
    end

    it 'defaults a bare hostname to https' do
      expect(described_class.asset_host_source('cdn-assets.newfoundlandlabrador.online'))
        .to eq('https://cdn-assets.newfoundlandlabrador.online')
    end

    it 'preserves non-default ports' do
      expect(described_class.asset_host_source('https://assets.example.test:8443/static'))
        .to eq('https://assets.example.test:8443')
    end
  end

  describe '.style_sources' do
    it 'includes the configured asset host origin' do
      sources = described_class.style_sources('https://cdn-assets.newfoundlandlabrador.online/assets')

      expect(sources).to include('https://cdn-assets.newfoundlandlabrador.online')
    end

    it 'does not duplicate the asset host origin' do
      sources = described_class.style_sources('https://cdn.jsdelivr.net/assets')

      expect(sources.count('https://cdn.jsdelivr.net')).to eq(1)
    end
  end

  describe '.script_sources' do
    it 'includes the configured asset host origin' do
      sources = described_class.script_sources('https://cdn-assets.newfoundlandlabrador.online/assets')

      expect(sources).to include('https://cdn-assets.newfoundlandlabrador.online')
    end
  end

  describe '.font_sources' do
    it 'includes the configured asset host origin' do
      sources = described_class.font_sources('https://cdn-assets.newfoundlandlabrador.online/assets')

      expect(sources).to include('https://cdn-assets.newfoundlandlabrador.online')
    end
  end

  describe '.img_sources' do
    it 'includes the configured asset host origin' do
      sources = described_class.img_sources('https://cdn-assets.newfoundlandlabrador.online/assets')

      expect(sources).to include('https://cdn-assets.newfoundlandlabrador.online')
    end
  end
end
