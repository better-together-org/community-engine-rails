# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe Css do
      describe 'Factory' do
        it 'has a valid factory' do
          css_block = build(:better_together_content_css)
          expect(css_block).to be_valid
        end

        it 'creates with custom CSS content' do
          css_block = create(:better_together_content_css, content_text: '.custom { color: blue; }')
          expect(css_block.content).to eq('.custom { color: blue; }')
        end
      end

      describe 'Associations' do
        it { is_expected.to have_many(:page_blocks).dependent(:destroy) }
        it { is_expected.to have_many(:pages).through(:page_blocks) }
      end

      describe 'Translatable Attributes' do
        it { is_expected.to respond_to(:content) }

        it 'supports translations for CSS content' do
          css_block = create(:better_together_content_css)

          I18n.with_locale(:en) do
            css_block.content = '.en-class { color: red; }'
            css_block.save!
          end

          I18n.with_locale(:fr) do
            css_block.content = '.fr-class { couleur: bleu; }'
            css_block.save!
          end

          expect(css_block.content_en).to eq('.en-class { color: red; }')
          expect(css_block.content_fr).to eq('.fr-class { couleur: bleu; }')
        end
      end

      describe 'Store Attributes' do
        describe 'css_settings' do
          it { is_expected.to respond_to(:css_settings) }
        end
      end

      describe 'Inheritance' do
        it 'inherits from Block' do
          expect(described_class.superclass).to eq(Block)
        end
      end
    end
  end
end
