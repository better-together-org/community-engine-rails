# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe Html do
      describe 'Factory' do
        it 'has a valid factory' do
          html_block = build(:better_together_content_html)
          expect(html_block).to be_valid
        end

        it 'creates with custom content' do
          html_block = create(:better_together_content_html, content: '<p>Custom HTML content</p>')
          expect(html_block.content).to eq('<p>Custom HTML content</p>')
        end
      end

      describe 'Associations' do
        it { is_expected.to have_many(:page_blocks).dependent(:destroy) }
        it { is_expected.to have_many(:pages).through(:page_blocks) }
      end

      describe 'Translatable Attributes' do
        it { is_expected.to respond_to(:content) }

        it 'supports translations for content' do
          html_block = create(:better_together_content_html)

          I18n.with_locale(:en) do
            html_block.content = '<p>English HTML</p>'
            html_block.save!
          end

          I18n.with_locale(:fr) do
            html_block.content = '<p>HTML Français</p>'
            html_block.save!
          end

          expect(html_block.content_en).to eq('<p>English HTML</p>')
          expect(html_block.content_fr).to eq('<p>HTML Français</p>')
        end
      end

      describe 'Store Attributes' do
        describe 'content_data' do
          it { is_expected.to respond_to(:content_data) }
          it { is_expected.to respond_to(:html_content) }
        end
      end

      describe 'Class Methods' do
        describe '.extra_permitted_attributes' do
          it 'returns an array' do
            expect(described_class.extra_permitted_attributes).to be_an(Array)
          end

          it 'includes html_content attribute' do
            expect(described_class.extra_permitted_attributes).to include(:html_content)
          end
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
