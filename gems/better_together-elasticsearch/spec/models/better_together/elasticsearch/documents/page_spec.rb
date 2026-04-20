# frozen_string_literal: true

require_relative '../../../../rails_helper'

RSpec.describe BetterTogether::Elasticsearch::Documents::Page do
  def fetch(hash, *keys)
    keys.reduce(hash) do |memo, key|
      break nil unless memo

      memo[key] || memo[key.to_s]
    end
  end

  it 'is mixed into the core page and block models by the extension engine' do
    expect(BetterTogether::Page.ancestors).to include(described_class)
    expect(BetterTogether::Content::Markdown.ancestors).to include(BetterTogether::Elasticsearch::Documents::Content::Markdown)
    expect(BetterTogether::Content::Template.ancestors).to include(BetterTogether::Elasticsearch::Documents::Content::Template)
  end

  describe '#as_indexed_json' do
    context 'with inline markdown blocks' do
      let(:page) do
        build(:better_together_page, title: 'Markdown Index Page', slug: 'markdown-index-page', privacy: 'public').tap do |record|
          record.markdown_blocks << build(
            :content_markdown,
            markdown_source: "# Heading\n\nSearchable paragraph with **formatting**."
          )
        end
      end

      it 'indexes plain text from markdown block content' do
        result = page.as_indexed_json
        markdown_block = fetch(result, 'markdown_blocks').first
        indexed_content = fetch(markdown_block, 'indexed_elasticsearch_content')
        localized_content = fetch(indexed_content, :localized_content)
        localized_value = fetch(localized_content, I18n.default_locale)

        expect(localized_value).to include('Heading')
        expect(localized_value).to include('Searchable paragraph with formatting.')
        expect(localized_value).not_to include('#')
        expect(localized_value).not_to include('**')
      end
    end

    context 'with file-based markdown blocks' do
      let(:markdown_file_path) { Rails.root.join('spec/fixtures/files/page_markdown_index.md') }
      let(:page) do
        FileUtils.mkdir_p(markdown_file_path.dirname)
        File.write(markdown_file_path, "# File Search\n\nFile body content that should be indexed.")

        build(
          :better_together_page,
          title: 'Markdown File Index Page',
          slug: 'markdown-file-index-page',
          privacy: 'public'
        ).tap do |record|
          record.markdown_blocks << build(
            :content_markdown,
            markdown_source: nil,
            markdown_file_path: markdown_file_path.to_s
          )
        end
      end

      after do
        FileUtils.rm_f(markdown_file_path)
      end

      it 'indexes plain text extracted from markdown files' do
        result = page.as_indexed_json
        markdown_block = fetch(result, 'markdown_blocks').first
        indexed_content = fetch(markdown_block, 'indexed_elasticsearch_content')
        localized_content = fetch(indexed_content, :localized_content)
        localized_value = fetch(localized_content, I18n.default_locale)

        expect(localized_value).to include('File Search')
        expect(localized_value).to include('File body content that should be indexed.')
        expect(localized_value).not_to include('#')
      end
    end

    context 'with template-backed page content' do
      let(:renderer) { instance_double(BetterTogether::TemplateRendererService, render_for_all_locales: { 'en' => 'Privacy content' }) }
      let(:page) do
        build(
          :better_together_page,
          title: 'Template Attribute Page',
          slug: 'template-attribute-page',
          privacy: 'public',
          template: 'better_together/static_pages/privacy'
        )
      end

      before do
        allow(BetterTogether::TemplateRendererService).to receive(:new)
          .with('better_together/static_pages/privacy')
          .and_return(renderer)
      end

      it 'renders template content through the extension document concern' do
        result = page.as_indexed_json

        expect(result['template_content']).to eq('en' => 'Privacy content')
        expect(BetterTogether::TemplateRendererService).to have_received(:new).with('better_together/static_pages/privacy')
      end
    end

    context 'with translated page content' do
      let(:token) { 'pagecontentsignal1006' }
      let(:page) do
        build(
          :better_together_page,
          title: 'Contentful Page',
          slug: 'contentful-page',
          privacy: 'public',
          content: "<p>#{token}</p>"
        )
      end

      it 'includes localized page content for elasticsearch indexing' do
        result = page.as_indexed_json

        expect(result.values.flatten.compact.join(' ')).to include(token)
      end
    end
  end
end
