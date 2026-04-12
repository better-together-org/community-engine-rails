# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurityPolicySources do
  describe '.normalize_origin' do
    it 'normalizes bare hostnames to https origins' do
      expect(described_class.normalize_origin('forms.btsdev.ca')).to eq('https://forms.btsdev.ca')
    end

    it 'preserves explicit https origins' do
      expect(described_class.normalize_origin('https://www.youtube.com')).to eq('https://www.youtube.com')
    end

    it 'rejects origins with paths or queries' do
      expect(described_class.normalize_origin('https://forms.btsdev.ca/s/abc')).to be_nil
      expect(described_class.normalize_origin('https://forms.btsdev.ca?x=1')).to be_nil
    end

    it 'rejects non-https origins' do
      expect(described_class.normalize_origin('http://forms.btsdev.ca')).to be_nil
    end
  end

  describe '.parse_origin_list' do
    it 'splits on commas and whitespace and deduplicates values' do
      origins = described_class.parse_origin_list("forms.btsdev.ca,\nhttps://www.youtube.com forms.btsdev.ca")

      expect(origins).to eq(['https://forms.btsdev.ca', 'https://www.youtube.com'])
    end
  end

  describe '.frame_ancestor_sources' do
    it 'falls back to none when no env or platform origins are configured' do
      host_platform = BetterTogether::Platform.find_by(host: true)
      host_platform.update!(
        settings: host_platform.settings.except('csp_frame_ancestors', 'csp_frame_src', 'csp_img_src')
      )

      proc_source = described_class.frame_ancestor_sources(nil).first
      context = Struct.new(:host).new('communityengine.app')

      expect(context.instance_exec(&proc_source)).to eq([:none])
    end
  end

  describe '.platform_sources_for_context' do
    let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

    it 'returns platform-specific origins for the current host app' do
      host_platform.update!(settings: host_platform.settings.merge('csp_frame_src' => ['https://forms.btsdev.ca']))

      context = Struct.new(:host).new('communityengine.app')

      expect(described_class.platform_sources_for_context(context, :csp_frame_src)).to eq(['https://forms.btsdev.ca'])
    end
  end

  describe '.script_sources' do
    let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

    it 'includes platform-configured script origins for the current host app' do
      host_platform.update!(settings: host_platform.settings.merge('csp_script_src' => ['https://scripts.example.com']))

      context = Struct.new(:host).new('communityengine.app')

      sources = context.instance_exec do
        BetterTogether::ContentSecurityPolicySources.script_sources(nil, nil).flat_map do |source|
          source.respond_to?(:call) ? instance_exec(&source) : source
        end
      end

      expect(sources).to include('https://scripts.example.com')
    end
  end

  describe '.connect_sources' do
    let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

    it 'includes platform-configured connection origins for the current host app' do
      host_platform.update!(settings: host_platform.settings.merge('csp_connect_src' => ['https://collector.example.com']))

      context = Struct.new(:host).new('communityengine.app')

      sources = context.instance_exec do
        BetterTogether::ContentSecurityPolicySources.connect_sources(nil).flat_map do |source|
          source.respond_to?(:call) ? instance_exec(&source) : source
        end
      end

      expect(sources).to include('https://collector.example.com')
    end
  end
end
