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
end
