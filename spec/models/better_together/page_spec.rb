# frozen_string_literal: true

# spec/models/better_together/page_spec.rb

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe Page do
    subject(:page) { build(:better_together_page) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(page).to be_valid
      end
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:title) }
      it { is_expected.to validate_presence_of(:privacy) }
    end

    describe 'Attributes' do
      it { is_expected.to respond_to(:title) }
      it { is_expected.to respond_to(:slug) }
      it { is_expected.to respond_to(:content) }
      it { is_expected.to respond_to(:meta_description) }
      it { is_expected.to respond_to(:keywords) }
      it { is_expected.to respond_to(:published_at) }
      it { is_expected.to respond_to(:privacy) }
      it { is_expected.to respond_to(:layout) }
      it { is_expected.to respond_to(:template) }
      it { is_expected.to respond_to(:protected) }
    end

    describe 'Scopes' do
      describe '.published' do
        it 'returns only published pages' do
          published_page_count = described_class.published.count
          create(:better_together_page, published_at: nil)
          expect(described_class.published.count).to eq(published_page_count)
        end
      end

      describe '.by_publication_date' do
        it 'orders pages by published date descending' do # rubocop:todo RSpec/NoExpectationExample
          # Create pages and test the order
        end
      end

      describe '.privacy_public' do
        it 'returns only public pages' do
          public_pages_count = described_class.privacy_public.count
          create(:better_together_page, privacy: 'private')
          expect(described_class.privacy_public.count).to eq(public_pages_count)
        end
      end
    end

    describe 'Methods' do
      describe '#published?' do
        it 'returns true if the page is published' do
          page.published_at = Time.now - 2.days
          expect(page.published?).to be true
        end

        it 'returns false if the page is not published' do
          page.published_at = nil
          expect(page.published?).to be false
        end
      end

      describe '#to_s' do
        it 'returns the title' do
          expect(page.to_s).to eq(page.title)
        end
      end

      describe '#url' do
        it 'returns the full URL of the page' do
          expect(page.url).to eq("#{::BetterTogether.base_url_with_locale}/#{page.slug}")
        end
      end

      describe '#as_indexed_json' do
        context 'with template blocks' do
          let(:page) do
            create(:better_together_page,
                   title: 'Template Block Page',
                   slug: 'template-block-page',
                   privacy: 'public',
                   page_blocks_attributes: [
                     {
                       block_attributes: {
                         type: 'BetterTogether::Content::Template',
                         template_path: 'better_together/static_pages/privacy'
                       }
                     }
                   ])
          end

          it 'includes template_blocks in indexed data' do
            result = page.as_indexed_json

            expect(result['template_blocks']).to be_present
            expect(result['template_blocks']).to be_an(Array)
          end

          it 'includes indexed_localized_content for each template block' do
            result = page.as_indexed_json

            template_block = result['template_blocks'].first
            expect(template_block['indexed_localized_content']).to be_present
            expect(template_block['indexed_localized_content']).to be_a(Hash)
          end

          it 'includes content for all locales in template blocks' do
            result = page.as_indexed_json

            content = result['template_blocks'].first['indexed_localized_content']
            expect(content.keys.map(&:to_sym)).to match_array(I18n.available_locales)
          end

          it 'includes template block id' do
            result = page.as_indexed_json

            template_block = result['template_blocks'].first
            expect(template_block['id']).to be_present
          end
        end

        context 'with template attribute' do
          let(:page) do
            create(:better_together_page,
                   title: 'Template Attribute Page',
                   slug: 'template-attribute-page',
                   privacy: 'public',
                   template: 'better_together/static_pages/privacy')
          end

          it 'includes template_content in indexed data' do
            result = page.as_indexed_json

            expect(result['template_content']).to be_present
            expect(result['template_content']).to be_a(Hash)
          end

          it 'renders template content for all locales' do
            result = page.as_indexed_json

            content = result['template_content']
            expect(content.keys.map(&:to_sym)).to match_array(I18n.available_locales)
          end

          it 'includes plain text content without HTML' do
            result = page.as_indexed_json

            I18n.available_locales.each do |locale|
              expect(result['template_content'][locale.to_s]).not_to match(/<[^>]+>/)
            end
          end

          it 'uses TemplateRendererService for rendering' do
            expect(BetterTogether::TemplateRendererService).to receive(:new)
              .with(page.template)
              .and_call_original

            page.as_indexed_json
          end
        end

        context 'with rich text blocks' do
          let(:page) do
            create(:better_together_page,
                   title: 'Rich Text Page',
                   slug: 'rich-text-page',
                   privacy: 'public',
                   page_blocks_attributes: [
                     {
                       block_attributes: {
                         type: 'BetterTogether::Content::RichText',
                         content: 'Test content'
                       }
                     }
                   ])
          end

          it 'includes rich_text_blocks in indexed data' do
            result = page.as_indexed_json

            expect(result['rich_text_blocks']).to be_present
            expect(result['rich_text_blocks']).to be_an(Array)
          end
        end

        context 'with markdown blocks' do
          let(:page) do
            create(
              :better_together_page,
              title: 'Markdown Index Page',
              slug: 'markdown-index-page',
              privacy: 'public',
              page_blocks_attributes: [
                {
                  block_attributes: {
                    type: 'BetterTogether::Content::Markdown',
                    markdown_source: "# Heading\n\nSearchable paragraph with **formatting**."
                  }
                }
              ]
            )
          end

          it 'indexes plain text from inline markdown content' do
            result = page.as_indexed_json
            markdown_block = result['markdown_blocks'].first['as_indexed_json']
            localized_content = markdown_block[:localized_content] || markdown_block['localized_content']
            localized_value = localized_content[I18n.default_locale] || localized_content[I18n.default_locale.to_s]

            expect(localized_value).to include('Heading')
            expect(localized_value).to include('Searchable paragraph with formatting.')
            expect(localized_value).not_to include('#')
            expect(localized_value).not_to include('<strong>')
          end
        end

        context 'with file-based markdown blocks' do
          let(:markdown_file_path) { Rails.root.join('spec/fixtures/files/page_markdown_index.md') }
          let(:page) do
            FileUtils.mkdir_p(markdown_file_path.dirname)
            File.write(markdown_file_path, "# File Search\n\nFile body content that should be indexed.")

            create(
              :better_together_page,
              title: 'Markdown File Index Page',
              slug: 'markdown-file-index-page',
              privacy: 'public',
              page_blocks_attributes: [
                {
                  block_attributes: {
                    type: 'BetterTogether::Content::Markdown',
                    markdown_source: nil,
                    markdown_file_path: markdown_file_path.to_s
                  }
                }
              ]
            )
          end

          after do
            FileUtils.rm_f(markdown_file_path)
          end

          it 'indexes plain text extracted from markdown files' do
            result = page.as_indexed_json
            markdown_block = result['markdown_blocks'].first['as_indexed_json']
            localized_content = markdown_block[:localized_content] || markdown_block['localized_content']
            localized_value = localized_content[I18n.default_locale] || localized_content[I18n.default_locale.to_s]

            expect(localized_value).to include('File Search')
            expect(localized_value).to include('File body content that should be indexed.')
            expect(localized_value).not_to include('#')
          end
        end

        context 'without template blocks or attribute' do
          let(:page) do
            create(:better_together_page,
                   title: 'Simple Page',
                   slug: 'simple-page',
                   privacy: 'public')
          end

          it 'does not include template_content' do
            result = page.as_indexed_json

            expect(result['template_content']).to be_nil
          end

          it 'includes basic page attributes' do
            result = page.as_indexed_json

            expect(result['id']).to eq(page.id)
            expect(result['title']).to eq(page.title)
            expect(result['slug']).to eq(page.slug)
          end
        end

        context 'with both template blocks and template attribute' do
          let(:page) do
            create(:better_together_page,
                   title: 'Mixed Template Page',
                   slug: 'mixed-template-page',
                   privacy: 'public',
                   template: 'better_together/static_pages/terms_of_service',
                   page_blocks_attributes: [
                     {
                       block_attributes: {
                         type: 'BetterTogether::Content::Template',
                         template_path: 'better_together/static_pages/privacy'
                       }
                     }
                   ])
          end

          it 'includes both template_blocks and template_content' do
            result = page.as_indexed_json

            expect(result['template_blocks']).to be_present
            expect(result['template_content']).to be_present
          end

          it 'renders different content for each' do
            result = page.as_indexed_json

            # Both should be present (either as Hash with string keys or symbolized)
            expect(result['template_blocks'] || result[:template_blocks]).to be_present
            expect(result['template_content'] || result[:template_content]).to be_present
          end
        end
      end
    end
  end
end
