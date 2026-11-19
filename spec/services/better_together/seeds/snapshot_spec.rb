# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seeds::Snapshot do
  describe '.covers?' do
    it 'accepts a stored hash that holds every key the packet names, plus defaults' do
      expect(described_class.covers?({ 'a' => '', 'b' => 'x' }, { 'a' => '' })).to be(true)
    end

    it 'rejects a stored hash that differs on a named key' do
      expect(described_class.covers?({ 'a' => 'edited' }, { 'a' => '' })).to be(false)
    end

    it 'compares nested hashes the same way' do
      expect(described_class.covers?({ 'a' => { 'b' => 1, 'c' => 2 } }, { 'a' => { 'b' => 1 } })).to be(true)
    end

    it 'compares scalars by equality' do
      expect([described_class.covers?('x', 'x'), described_class.covers?('x', 'y'), described_class.covers?(nil, 'y')])
        .to eq([true, false, false])
    end
  end
end
