# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::Markdown do
  describe 'associations' do
    it { is_expected.to have_many(:page_blocks).dependent(:destroy) }
    it { is_expected.to have_many(:pages).through(:page_blocks) }
  end

  describe 'validations' do
    context 'when markdown_source is provided' do
      subject { described_class.new(markdown_source: '# Hello World') }

      it { is_expected.to be_valid }
      it { is_expected.not_to validate_presence_of(:markdown_file_path) }
    end

    context 'when markdown_file_path is provided' do
      subject { described_class.new(markdown_file_path: file_path.to_s) }

      let(:file_path) { Rails.root.join('spec/fixtures/files/test_markdown.md') }

      before do
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, '# Test Content')
      end

      after do
        FileUtils.rm_f(file_path)
      end

      it { is_expected.to be_valid }
    end

    context 'when neither source nor file_path is provided' do
      subject(:markdown_block) { described_class.new }

      it 'is invalid' do
        expect(markdown_block).not_to be_valid
        expect(markdown_block.errors[:base]).to include('Either markdown source or file path must be provided')
      end
    end

    context 'when file_path does not exist' do
      subject(:markdown_block) { described_class.new(markdown_file_path: '/nonexistent/file.md') }

      it 'is invalid' do
        expect(markdown_block).not_to be_valid
        expect(markdown_block.errors[:markdown_file_path]).to include('file does not exist')
      end
    end

    context 'when file_path has wrong extension' do
      subject(:markdown_block) { described_class.new(markdown_file_path: file_path.to_s) }

      let(:file_path) { Rails.root.join('spec/fixtures/files/test_file.txt') }

      before do
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, 'Some content')
      end

      after do
        FileUtils.rm_f(file_path)
      end

      it 'is invalid' do
        expect(markdown_block).not_to be_valid
        expect(markdown_block.errors[:markdown_file_path]).to include('must be a markdown file (.md or .markdown)')
      end
    end

    context 'when file has .markdown extension' do
      subject { described_class.new(markdown_file_path: file_path.to_s) }

      let(:file_path) { Rails.root.join('spec/fixtures/files/test.markdown') }

      before do
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, '# Test')
      end

      after do
        FileUtils.rm_f(file_path)
      end

      it { is_expected.to be_valid }
    end
  end

  describe '#content' do
    context 'when using markdown_source' do
      let(:markdown) { described_class.new(markdown_source: '# Hello **World**') }

      it 'returns the markdown_source' do
        expect(markdown.content).to eq('# Hello **World**')
      end
    end

    context 'when using markdown_file_path' do
      let(:file_path) { Rails.root.join('spec/fixtures/files/content_test.md') }
      let(:markdown) { described_class.new(markdown_file_path: file_path.to_s) }
      let(:file_content) { "# File Content\n\nThis is from a file." }

      before do
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, file_content)
      end

      after do
        FileUtils.rm_f(file_path)
      end

      it 'returns the file content' do
        expect(markdown.content).to eq(file_content)
      end
    end

    context 'when using relative file path' do
      let(:file_path) { 'spec/fixtures/files/relative_test.md' }
      let(:markdown) { described_class.new(markdown_file_path: file_path) }
      let(:full_path) { Rails.root.join(file_path) }
      let(:file_content) { '# Relative Path Test' }

      before do
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, file_content)
      end

      after do
        FileUtils.rm_f(full_path)
      end

      it 'resolves the relative path' do
        expect(markdown.content).to eq(file_content)
      end
    end

    context 'when file does not exist' do
      let(:markdown) { described_class.new(markdown_file_path: '/tmp/nonexistent.md') }

      it 'returns empty string' do
        # Skip validation
        markdown.save(validate: false)
        expect(markdown.content).to eq('')
      end
    end

    context 'when both source and file_path are provided' do
      let(:file_path) { Rails.root.join('spec/fixtures/files/both_test.md') }
      let(:markdown) do
        described_class.new(
          markdown_source: '# Source Content',
          markdown_file_path: file_path.to_s
        )
      end

      before do
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, '# File Content')
      end

      after do
        FileUtils.rm_f(file_path)
      end

      it 'prefers markdown_source' do
        expect(markdown.content).to eq('# Source Content')
      end
    end
  end

  describe '#rendered_html' do
    let(:markdown) { described_class.new(markdown_source: markdown_source) }

    context 'with basic markdown' do
      let(:markdown_source) { '# Hello World' }

      it 'renders markdown to HTML' do
        html = markdown.rendered_html
        expect(html).to include('<h1')
        expect(html).to include('Hello World')
      end

      it 'returns HTML-safe content' do
        expect(markdown.rendered_html).to be_html_safe
      end
    end

    context 'with complex markdown' do
      let(:markdown_source) do
        <<~MD
          # Main Title

          This is a paragraph with **bold** and *italic* text.

          ## Subheading

          - List item 1
          - List item 2

          ```ruby
          def hello
            puts "world"
          end
          ```

          [Link](https://example.com)
        MD
      end

      it 'renders all markdown features' do
        html = markdown.rendered_html

        expect(html).to include('<h1')
        expect(html).to include('<h2')
        expect(html).to include('<strong>bold</strong>')
        expect(html).to include('<em>italic</em>')
        expect(html).to include('<ul>')
        expect(html).to include('<li>')
        expect(html).to include('<code')
        expect(html).to include('<a href')
      end
    end

    context 'with tables' do
      let(:markdown_source) do
        <<~MD
          | Header 1 | Header 2 |
          |----------|----------|
          | Cell 1   | Cell 2   |
        MD
      end

      it 'renders tables' do
        html = markdown.rendered_html
        expect(html).to include('<table>')
        expect(html).to include('<thead>')
        expect(html).to include('<tbody>')
      end
    end

    context 'with strikethrough' do
      let(:markdown_source) { '~~strikethrough~~' }

      it 'renders strikethrough' do
        html = markdown.rendered_html
        expect(html).to include('<del>strikethrough</del>')
      end
    end
  end

  describe '#rendered_plain_text' do
    let(:markdown) { described_class.new(markdown_source: markdown_source) }

    context 'with basic markdown' do
      let(:markdown_source) { '# Hello **World**' }

      it 'returns plain text without HTML tags' do
        plain = markdown.rendered_plain_text
        expect(plain).not_to match(/<[^>]+>/)
        expect(plain).to include('Hello')
        expect(plain).to include('World')
      end
    end

    context 'with complex markdown' do
      let(:markdown_source) do
        <<~MD
          # Title

          This is **bold** and *italic*.

          - Item 1
          - Item 2
        MD
      end

      it 'extracts all text content' do
        plain = markdown.rendered_plain_text
        expect(plain).to include('Title')
        expect(plain).to include('bold')
        expect(plain).to include('italic')
        expect(plain).to include('Item 1')
        expect(plain).to include('Item 2')
      end
    end
  end

  describe '#as_indexed_json' do
    let(:markdown_source) { '# Searchable Content' }
    let(:markdown) { described_class.create!(markdown_source: markdown_source) }

    it 'returns a hash with id and localized_content' do
      result = markdown.as_indexed_json

      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly(:id, :localized_content)
    end

    it 'includes the markdown id' do
      result = markdown.as_indexed_json
      expect(result[:id]).to eq(markdown.id)
    end

    it 'includes localized content' do
      result = markdown.as_indexed_json

      expect(result[:localized_content]).to be_a(Hash)
      expect(result[:localized_content].keys).to match_array(I18n.available_locales)
    end

    it 'includes plain text content for each locale' do
      result = markdown.as_indexed_json

      I18n.available_locales.each do |locale|
        expect(result[:localized_content][locale]).to be_a(String)
        expect(result[:localized_content][locale]).to include('Searchable Content')
      end
    end
  end

  describe 'integration with Page model' do
    let(:page) do
      BetterTogether::Page.create!(
        title: 'Markdown Test Page',
        slug: 'markdown-test',
        privacy: 'public',
        page_blocks_attributes: [
          {
            block_attributes: {
              type: 'BetterTogether::Content::Markdown',
              markdown_source: '# Test Markdown Content'
            }
          }
        ]
      )
    end

    it 'can be associated with pages through page_blocks' do
      expect(page.content_blocks.count).to eq(1)
      expect(page.content_blocks.first).to be_a(described_class)
    end

    it 'is included in page indexed data' do
      indexed_data = page.as_indexed_json
      expect(indexed_data).to be_present
    end
  end

  describe 'store_attributes' do
    it 'stores markdown_source via Mobility (not in content_data)' do
      markdown = described_class.new(markdown_source: '# Test')
      # markdown_source is now stored via Mobility translations, not storext
      expect(markdown.markdown_source).to eq('# Test')
      expect(markdown.content_data).not_to include('markdown_source')
    end

    it 'stores markdown_file_path in content_data' do
      markdown = described_class.new(markdown_file_path: '/path/to/file.md')
      expect(markdown.content_data).to include('markdown_file_path')
    end

    it 'stores auto_sync_from_file in content_data' do
      markdown = described_class.new(auto_sync_from_file: true)
      expect(markdown.content_data).to include('auto_sync_from_file')
      expect(markdown.auto_sync_from_file).to be true
    end
  end

  describe 'caching' do
    let(:markdown) { described_class.create!(markdown_source: '# Cached Content') }

    it 'has a cache_key_with_version' do
      expect(markdown.cache_key_with_version).to be_present
    end

    it 'cache key changes when content updates' do
      original_key = markdown.cache_key_with_version
      markdown.update!(markdown_source: '# Updated Content')
      expect(markdown.cache_key_with_version).not_to eq(original_key)
    end
  end

  describe '#contains_mermaid?' do
    context 'when content has mermaid code blocks' do
      let(:markdown) do
        described_class.new(markdown_source: <<~MD)
          # Documentation

          ```mermaid
          graph TD
            A-->B
          ```
        MD
      end

      it 'returns true' do
        expect(markdown.contains_mermaid?).to be true
      end
    end

    context 'when content has mermaid file references with parentheses' do
      let(:markdown) do
        described_class.new(markdown_source: '![Diagram](path/to/diagram.mmd)')
      end

      it 'returns true' do
        expect(markdown.contains_mermaid?).to be true
      end
    end

    context 'when content has mermaid file references with brackets' do
      let(:markdown) do
        described_class.new(markdown_source: '[Diagram](diagrams/flow.mmd)')
      end

      it 'returns true' do
        expect(markdown.contains_mermaid?).to be true
      end
    end

    context 'when content has no mermaid diagrams' do
      let(:markdown) do
        described_class.new(markdown_source: <<~MD)
          # Documentation

          ```ruby
          def hello
            puts "world"
          end
          ```
        MD
      end

      it 'returns false' do
        expect(markdown.contains_mermaid?).to be false
      end
    end

    context 'when content is empty' do
      let(:markdown) { described_class.new(markdown_source: '') }

      it 'returns false' do
        expect(markdown.contains_mermaid?).to be false
      end
    end

    context 'when content is nil' do
      let(:markdown) { described_class.new }

      it 'returns false' do
        expect(markdown.contains_mermaid?).to be false
      end
    end
  end
end
