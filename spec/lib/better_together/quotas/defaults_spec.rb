# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Quotas::Defaults do
  include AutomaticTestConfiguration

  before do
    configure_host_platform
    described_class.reset!
  end

  after { described_class.reset! }

  describe '.yaml_value' do
    it 'reads the gem defaults' do
      expect(described_class.yaml_value('media_storage', 'person')).to eq(250_000_000)
      expect(described_class.yaml_value('media_storage', 'community')).to eq(1_000_000_000)
      expect(described_class.yaml_value('media_storage', 'platform')).to eq(10_000_000_000)
    end

    it 'is nil for an unknown type' do
      expect(described_class.yaml_value('nope', 'person')).to be_nil
    end
  end

  describe 'merging host files' do
    it 'deep-merges a later file over the gem file, keeping untouched values' do
      Dir.mktmpdir do |dir|
        host = Pathname.new(dir).join('quota_defaults.yml')
        host.write("quotas:\n  media_storage:\n    person: 5\n")
        allow(described_class).to receive(:files).and_return([BetterTogether::Engine.root.join('config/quota_defaults.yml'), host])

        expect(described_class.yaml_value('media_storage', 'person')).to eq(5)
        expect(described_class.yaml_value('media_storage', 'community')).to eq(1_000_000_000)
      end
    end

    it 'rejects an unknown owner kind' do
      Dir.mktmpdir do |dir|
        host = Pathname.new(dir).join('quota_defaults.yml')
        host.write("quotas:\n  media_storage:\n    robot: 5\n")
        allow(described_class).to receive(:files).and_return([host])

        expect { described_class.table }.to raise_error(described_class::InvalidDefaultsError, /owner kind/)
      end
    end

    it 'rejects a negative or non-integer limit' do
      Dir.mktmpdir do |dir|
        host = Pathname.new(dir).join('quota_defaults.yml')
        host.write("quotas:\n  media_storage:\n    person: -1\n")
        allow(described_class).to receive(:files).and_return([host])

        expect { described_class.table }.to raise_error(described_class::InvalidDefaultsError, /non-negative/)
      end
    end
  end

  describe '.for' do
    it 'falls back to YAML when the platform has no override' do
      person = create(:better_together_person)
      expect(described_class.for(type: 'media_storage', owner: person)).to eq(250_000_000)
    end

    it 'lets the owning platform override beat YAML, per kind' do
      person = create(:better_together_person)
      person.platform.update!(quota_default_limits: { 'media_storage' => { 'person' => 7 } })

      expect(described_class.for(type: 'media_storage', owner: person)).to eq(7)
      expect(described_class.for(type: 'media_storage', owner: create(:better_together_community, platform: person.platform)))
        .to eq(1_000_000_000)
    end

    it 'uses the platform itself as the settings source for a platform owner' do
      platform = create(:better_together_platform)
      platform.update!(quota_default_limits: { 'media_storage' => { 'platform' => 9 } })

      expect(described_class.for(type: 'media_storage', owner: platform)).to eq(9)
    end
  end

  describe '.restrict_to_storage_steps' do
    it 'keeps listed steps and the configured default, drops other byte values' do
      result = described_class.restrict_to_storage_steps(
        'media_storage' => { 'person' => '250000000', 'community' => '1000000000', 'platform' => '5' }
      )

      expect(result).to eq('media_storage' => { 'person' => 250_000_000, 'community' => 1_000_000_000 })
    end

    it 'lets non-byte quota types through unchanged' do
      expect(described_class.restrict_to_storage_steps('ai_translation_tokens' => { 'person' => '12345' }))
        .to eq('ai_translation_tokens' => { 'person' => 12_345 })
    end
  end
end
