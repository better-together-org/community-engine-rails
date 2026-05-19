# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe AlertBlock do
      subject(:block) { described_class.new(alert_level: 'info') }

      it 'is a subclass of Content::Block' do
        expect(described_class.superclass).to eq(BetterTogether::Content::Block)
      end

      it 'is content_addable' do
        expect(described_class.content_addable?).to be true
      end

      describe 'defaults' do
        it 'defaults alert_level to info' do
          expect(described_class.new.alert_level).to eq('info')
        end

        it 'defaults dismissible to false' do
          expect(described_class.new.dismissible).to eq('false')
        end
      end

      describe 'validations' do
        it 'validates alert_level inclusion' do
          block.alert_level = 'critical'
          block.valid?
          expect(block.errors[:alert_level]).not_to be_empty
        end

        it 'accepts all valid alert levels' do
          AlertBlock::ALERT_LEVELS.each do |l|
            block.alert_level = l
            block.valid?
            expect(block.errors[:alert_level]).to be_empty
          end
        end
      end

      describe '#dismissible?' do
        it 'returns false when dismissible is "false"' do
          block.dismissible = 'false'
          expect(block.dismissible?).to be false
        end

        it 'returns true when dismissible is "true"' do
          block.dismissible = 'true'
          expect(block.dismissible?).to be true
        end
      end
    end
  end
end
