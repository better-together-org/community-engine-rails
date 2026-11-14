# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformSettingsRegistry do
  around { |example| with_registered_platform_settings { example.run } }

  describe '.register' do
    it 'stores a definition addressable by key' do
      BetterTogether.register_platform_setting('thing.enabled', type: :boolean, label: 'Enabled')

      expect(described_class.find('thing.enabled')).to have_attributes(group: 'thing', field: 'enabled', type: :boolean)
    end

    it 'rejects keys without a group and field' do
      expect { BetterTogether.register_platform_setting('nogroup') }.to raise_error(ArgumentError, /invalid/)
    end

    it 'rejects unknown types and non-callable validators' do
      expect { BetterTogether.register_platform_setting('a.b', type: :blob) }.to raise_error(ArgumentError, /type/)
      expect { BetterTogether.register_platform_setting('a.b', validator: 'x') }.to raise_error(ArgumentError, /call/)
    end

    it 'replaces an earlier definition with the same key' do
      BetterTogether.register_platform_setting('a.b', label: 'One')
      BetterTogether.register_platform_setting('a.b', label: 'Two')

      expect(described_class.find('a.b').label).to eq('Two')
    end
  end

  describe 'Definition#error_for' do
    it 'checks patterns, options and custom validators and ignores blanks' do # rubocop:disable RSpec/MultipleExpectations
      BetterTogether.register_platform_setting('a.id', pattern: /\AG-\d+\z/)
      BetterTogether.register_platform_setting('a.mode', type: :select, options: %w[x y])
      BetterTogether.register_platform_setting('a.even', validator: ->(v) { 'must be even' if v.to_i.odd? })

      expect(described_class.find('a.id').error_for('nope')).to be_present
      expect(described_class.find('a.id').error_for('G-12')).to be_nil
      expect(described_class.find('a.id').error_for('')).to be_nil
      expect(described_class.find('a.mode').error_for('z')).to be_present
      expect(described_class.find('a.even').error_for('3')).to eq('must be even')
    end
  end
end
