# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe RichText do
      describe 'Factory' do
        it 'has a valid factory' do
          rich_text_block = build(:better_together_content_rich_text)
          expect(rich_text_block).to be_valid
        end

        it 'creates with custom content' do
          rich_text_block = create(:better_together_content_rich_text, content_html: '<h1>Custom Heading</h1>')
          expect(rich_text_block.content.to_s).to include('Custom Heading')
        end
      end

      describe 'Associations' do
        it { is_expected.to have_many(:page_blocks).dependent(:destroy) }
        it { is_expected.to have_many(:pages).through(:page_blocks) }
      end

      describe 'Inheritance' do
        it 'inherits from Block' do
          expect(described_class.superclass).to eq(Block)
        end
      end

      describe 'Translatable Attributes' do
        it { is_expected.to respond_to(:content) }

        it 'supports translations for content via Action Text' do
          rich_text_block = create(:better_together_content_rich_text)

          I18n.with_locale(:en) do
            rich_text_block.content = '<p>English content</p>'
            rich_text_block.save!
          end

          I18n.with_locale(:fr) do
            rich_text_block.content = '<p>Contenu français</p>'
            rich_text_block.save!
          end

          I18n.with_locale(:en) do
            expect(rich_text_block.content.to_s).to include('English content')
          end

          I18n.with_locale(:fr) do
            expect(rich_text_block.content.to_s).to include('Contenu français')
          end
        end
      end

      describe 'Action Text Integration' do
        it 'uses Action Text backend for content translation' do
          rich_text_block = create(:better_together_content_rich_text)
          expect(rich_text_block.content).to be_a(ActionText::RichText)
        end

        it 'preserves HTML formatting' do
          rich_text_block = create(:better_together_content_rich_text,
                                   content_html: '<h1>Heading</h1><p>Paragraph</p>')
          content_string = rich_text_block.content.to_s
          expect(content_string).to include('<h1>Heading</h1>')
          expect(content_string).to include('<p>Paragraph</p>')
        end
      end

      describe 'Store Attributes' do
        describe 'custom_css' do
          it { is_expected.to respond_to(:css_classes) }

          it 'can store custom CSS classes' do
            rich_text_block = create(:better_together_content_rich_text)
            rich_text_block.update(css_classes: 'container mt-4')
            expect(rich_text_block.css_classes).to eq('container mt-4')
          end

          it 'has default my-5 CSS classes' do
            rich_text_block = create(:better_together_content_rich_text)
            expect(rich_text_block.css_classes).to eq('my-5')
          end
        end
      end

      describe 'Instance Methods' do
        describe '#indexed_localized_content' do
          it 'returns hash with localized plain text content' do
            rich_text_block = create(:better_together_content_rich_text,
                                     content_html: '<p>Searchable content</p>')

            localized_content = rich_text_block.indexed_localized_content
            expect(localized_content).to be_an(Array)
            expect(localized_content.first).to include('Searchable content')
          end

          it 'strips HTML tags for indexing' do
            rich_text_block = create(:better_together_content_rich_text,
                                     content_html: '<strong>Bold</strong> text')

            localized_content = rich_text_block.indexed_localized_content
            expect(localized_content.first).not_to include('<strong>')
            expect(localized_content.first).to include('Bold')
          end
        end

        describe '#as_indexed_json' do
          it 'includes basic attributes for Elasticsearch indexing' do
            rich_text_block = create(:better_together_content_rich_text)
            json = rich_text_block.as_indexed_json

            expect(json).to have_key(:id)
            expect(json).to have_key(:identifier)
            expect(json).to have_key(:localized_content)
          end

          it 'includes indexed_localized_content' do
            rich_text_block = create(:better_together_content_rich_text,
                                     content_html: '<p>Test content</p>')

            json = rich_text_block.as_indexed_json
            expect(json[:localized_content]).to be_an(Array)
            expect(json[:localized_content].first).to include('Test content')
          end
        end
      end
    end
  end
end
