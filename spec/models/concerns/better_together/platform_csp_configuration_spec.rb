# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe PlatformCspConfiguration, :skip_host_setup do
    subject(:platform) { build(:better_together_platform) }

    describe 'constants' do
      it 'defines all five CSP setting keys' do
        expect(described_class::CSP_SETTING_KEYS.keys).to match_array(%i[
                                                                        csp_frame_ancestors_text
                                                                        csp_frame_src_text
                                                                        csp_img_src_text
                                                                        csp_script_src_text
                                                                        csp_connect_src_text
                                                                      ])
      end

      it 'maps text attribute names to settings storage keys' do
        expect(described_class::CSP_SETTING_KEYS[:csp_frame_ancestors_text]).to eq('csp_frame_ancestors')
        expect(described_class::CSP_SETTING_KEYS[:csp_img_src_text]).to eq('csp_img_src')
      end
    end

    describe 'CSP getter methods' do
      before do
        platform.settings = {
          'csp_frame_ancestors' => ['https://example.com', 'https://example.org'],
          'csp_frame_src' => ['https://embed.example.com'],
          'csp_img_src' => ['https://images.example.com', 'https://images.example.com'],
          'csp_script_src' => ['https://cdn.example.com'],
          'csp_connect_src' => ['https://api.example.com']
        }
      end

      it 'returns csp_frame_ancestors from settings' do
        expect(platform.csp_frame_ancestors).to eq(['https://example.com', 'https://example.org'])
      end

      it 'returns csp_frame_src from settings' do
        expect(platform.csp_frame_src).to eq(['https://embed.example.com'])
      end

      it 'returns csp_img_src from settings' do
        expect(platform.csp_img_src).to eq(['https://images.example.com'])
      end

      it 'returns csp_script_src from settings' do
        expect(platform.csp_script_src).to eq(['https://cdn.example.com'])
      end

      it 'returns csp_connect_src from settings' do
        expect(platform.csp_connect_src).to eq(['https://api.example.com'])
      end

      it 'deduplicates values' do
        platform.settings['csp_img_src'] = ['https://images.example.com', 'https://images.example.com']
        expect(platform.csp_img_src.length).to eq(1)
      end

      it 'returns an empty array when setting key absent' do
        expect(platform.csp_frame_ancestors).to respond_to(:each)
        platform.settings = {}
        expect(platform.csp_frame_ancestors).to eq([])
      end
    end

    describe 'CSP text getter/setter round-trip' do
      it 'joins stored values with newlines for text getter' do
        platform.settings = { 'csp_frame_src' => ['https://a.example.com', 'https://b.example.com'] }
        expect(platform.csp_frame_src_text).to eq("https://a.example.com\nhttps://b.example.com")
      end

      it 'returns empty string when no values stored' do
        platform.settings = {}
        expect(platform.csp_frame_src_text).to eq('')
      end

      it 'text setter overrides stored value for text getter' do
        platform.settings = { 'csp_frame_ancestors' => ['https://stored.example.com'] }
        platform.csp_frame_ancestors_text = 'https://override.example.com'
        expect(platform.csp_frame_ancestors_text).to eq('https://override.example.com')
      end

      it 'persists text setter value into settings after validation' do
        platform.csp_frame_ancestors_text = "https://a.example.com\nhttps://b.example.com"
        platform.valid?
        expect(platform.settings['csp_frame_ancestors']).to contain_exactly(
          'https://a.example.com',
          'https://b.example.com'
        )
      end

      it 'removes setting key when text is cleared' do
        platform.settings = { 'csp_frame_src' => ['https://a.example.com'] }
        platform.csp_frame_src_text = ''
        platform.valid?
        expect(platform.settings.key?('csp_frame_src')).to be false
      end

      it 'normalizes bare hostnames to https origins' do
        platform.csp_frame_ancestors_text = 'example.com'
        platform.valid?
        expect(platform.settings['csp_frame_ancestors']).to contain_exactly('https://example.com')
      end
    end

    describe 'CSP origin validation' do
      it 'is valid with well-formed HTTPS origins' do
        platform.csp_frame_src_text = "https://a.example.com\nhttps://b.example.com"
        expect(platform).to be_valid
      end

      it 'adds an error for HTTP origins' do
        platform.csp_frame_src_text = 'http://insecure.example.com'
        expect(platform).not_to be_valid
        expect(platform.errors[:csp_frame_src_text]).to be_present
      end

      it 'adds an error for path-qualified origins' do
        platform.csp_frame_src_text = 'https://example.com/some/path'
        expect(platform).not_to be_valid
        expect(platform.errors[:csp_frame_src_text]).to be_present
      end

      it 'adds an error for javascript: origins' do
        platform.csp_script_src_text = 'javascript:alert(1)'
        expect(platform).not_to be_valid
        expect(platform.errors[:csp_script_src_text]).to be_present
      end

      it 'does not validate fields that were never assigned' do
        # No text attrs set — only settings stored values, no ivar present
        platform.settings = { 'csp_frame_src' => ['https://stored.example.com'] }
        expect(platform).to be_valid
      end
    end

    describe 'default CSP seeding on create' do
      it 'seeds Leaflet tile origins for local platforms' do
        local_platform = create(:better_together_platform)
        expect(local_platform.csp_img_src).to include('https://*.tile.openstreetmap.org')
      end

      it 'does not seed Leaflet tile origins for external platforms' do
        external_platform = create(:better_together_platform, :external)
        expect(external_platform.csp_img_src).not_to include('https://*.tile.openstreetmap.org')
      end

      it 'merges with any csp_img_src already set at create time' do
        platform = create(:better_together_platform,
                          csp_img_src_text: 'https://cdn.example.com')
        expect(platform.csp_img_src).to include('https://*.tile.openstreetmap.org')
        expect(platform.csp_img_src).to include('https://cdn.example.com')
      end

      it 'does not re-seed on subsequent saves' do
        platform = create(:better_together_platform)
        platform.update!(name: "#{platform.name} updated")
        # No duplicate seeding — DEFAULT_LOCAL_CSP_IMG_SOURCES applied on: :create only
        expect(platform.csp_img_src.count('https://*.tile.openstreetmap.org')).to eq(1)
      end
    end
  end
end
