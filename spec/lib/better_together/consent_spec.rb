# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Consent do
  after { described_class.reset! }

  describe '.parse' do
    it 'reads a valid decision' do
      expect(described_class.parse('{"v":1,"analytics":true,"marketing":false}'))
        .to eq('analytics' => true, 'marketing' => false)
    end

    it 'treats missing, malformed or wrong-version cookies as undecided', :aggregate_failures do
      expect(described_class.parse(nil)).to be_nil
      expect(described_class.parse('not json')).to be_nil
      expect(described_class.parse('{"v":2,"analytics":true}')).to be_nil
    end

    it 'only accepts literal true as consent' do
      expect(described_class.parse('{"v":1,"analytics":"yes","marketing":1}'))
        .to eq('analytics' => false, 'marketing' => false)
    end
  end

  describe '.provider_requires?' do
    let(:platform) { instance_double(BetterTogether::Platform) }

    it 'is false with no providers' do
      expect(described_class.provider_requires?(platform)).to be(false)
    end

    it 'is true when any provider asks for consent' do
      BetterTogether.register_consent_provider(:a) { false }
      BetterTogether.register_consent_provider(:b) { true }

      expect(described_class.provider_requires?(platform)).to be(true)
    end

    it 'fails toward showing the banner when a provider raises' do
      BetterTogether.register_consent_provider(:broken) { raise 'boom' }

      expect(described_class.provider_requires?(platform)).to be(true)
    end
  end

  describe '.provider_categories' do
    let(:platform) { instance_double(BetterTogether::Platform) }

    it 'treats true as every category and a symbol or list as exactly those', :aggregate_failures do
      BetterTogether.register_consent_provider(:all) { true }
      expect(described_class.provider_categories(platform)).to match_array(%w[analytics marketing])

      described_class.reset!
      BetterTogether.register_consent_provider(:ga) { :analytics }
      expect(described_class.provider_categories(platform)).to eq(%w[analytics])
    end

    it 'ignores false, empty and unknown categories', :aggregate_failures do
      BetterTogether.register_consent_provider(:a) { false }
      BetterTogether.register_consent_provider(:b) { [] }
      BetterTogether.register_consent_provider(:c) { :tracking }

      expect(described_class.provider_categories(platform)).to be_empty
      expect(described_class.provider_requires?(platform)).to be(false)
    end

    it 'counts a raising provider as using every category' do
      BetterTogether.register_consent_provider(:broken) { raise 'boom' }

      expect(described_class.provider_categories(platform)).to match_array(%w[analytics marketing])
    end
  end

  describe '.policy_version' do
    let(:platform) { instance_double(BetterTogether::Platform) }

    it 'is stable for the same registrations and changes when a provider changes category', :aggregate_failures do
      BetterTogether.register_consent_provider(:ga) { :analytics }
      first = described_class.policy_version(platform)
      expect(described_class.policy_version(platform)).to eq(first)

      BetterTogether.register_consent_provider(:ga) { %i[analytics marketing] }
      expect(described_class.policy_version(platform)).not_to eq(first)
    end
  end

  describe 'cookie value' do
    it 'round-trips a decision with its policy version', :aggregate_failures do
      raw = described_class.serialize({ 'analytics' => true }, 'abc123')

      expect(described_class.parse(raw)).to eq('analytics' => true, 'marketing' => false)
      expect(described_class.parse_policy_version(raw)).to eq('abc123')
    end

    it 'has no policy version for a cookie that predates it' do
      expect(described_class.parse_policy_version('{"v":1,"analytics":true}')).to be_nil
    end
  end

  describe '.cookie_options' do
    it 'matches the attributes the banner script sets', :aggregate_failures do
      options = described_class.cookie_options(secure: true)

      expect(options).to include(path: '/', same_site: :lax, secure: true, httponly: false)
      expect(options[:expires]).to be_within(1.minute).of(180.days.from_now)
    end
  end
end
