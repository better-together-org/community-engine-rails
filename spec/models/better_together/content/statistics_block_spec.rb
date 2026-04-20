# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe StatisticsBlock do
      subject(:block) { described_class.new(columns: '3') }

      it 'is a subclass of Content::Block' do
        expect(described_class.superclass).to eq(BetterTogether::Content::Block)
      end

      it 'is not content_addable pending deferred rollout review' do
        expect(described_class.content_addable?).to be false
      end

      describe 'defaults' do
        it 'defaults columns to 3' do
          expect(described_class.new.columns).to eq('3')
        end

        it 'defaults stats_json to empty array string' do
          expect(described_class.new.stats_json).to eq('[]')
        end
      end

      describe 'validations' do
        it 'validates columns inclusion' do
          block.columns = '5'
          block.valid?
          expect(block.errors[:columns]).not_to be_empty
        end

        it 'accepts all valid column counts' do
          StatisticsBlock::COLUMN_OPTIONS.each do |c|
            block.columns = c
            block.valid?
            expect(block.errors[:columns]).to be_empty
          end
        end
      end

      describe '#parsed_stats' do
        it 'returns [] for empty array JSON' do
          block.stats_json = '[]'
          expect(block.parsed_stats).to eq([])
        end

        it 'parses valid JSON array with symbolized keys' do
          block.stats_json = '[{"label":"Members","value":"500","icon":"fas fa-users"}]'
          result = block.parsed_stats
          expect(result.first).to include(label: 'Members', value: '500')
        end

        it 'returns [] on invalid JSON' do
          block.stats_json = 'not json'
          expect(block.parsed_stats).to eq([])
        end
      end
    end
  end
end
