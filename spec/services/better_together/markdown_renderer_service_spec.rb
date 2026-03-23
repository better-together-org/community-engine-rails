# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::MarkdownRendererService do
  describe '#render_html' do
    context 'with basic markdown' do
      let(:service) { described_class.new('# Hello World') }

      it 'renders markdown to HTML' do
        html = service.render_html
        expect(html).to include('<h1')
        expect(html).to include('Hello World')
      end

      it 'returns HTML-safe content' do
        expect(service.render_html).to be_html_safe
      end
    end

    context 'with complex markdown features' do
      let(:markdown_source) do
        <<~MD
          # Main Title

          This is a paragraph with **bold** and *italic* text.

          ## Subheading

          - List item 1
          - List item 2

          1. Numbered item
          2. Another item

          ```ruby
          def hello
            puts "world"
          end
          ```

          [External Link](https://example.com)
          [Internal Link](/about)
        MD
      end
      let(:service) { described_class.new(markdown_source) }

      it 'renders headings' do
        html = service.render_html
        expect(html).to include('<h1')
        expect(html).to include('Main Title')
        expect(html).to include('<h2')
        expect(html).to include('Subheading')
      end

      it 'renders emphasis' do
        html = service.render_html
        expect(html).to include('<strong>bold</strong>')
        expect(html).to include('<em>italic</em>')
      end

      it 'renders unordered lists' do
        html = service.render_html
        expect(html).to include('<ul>')
        expect(html).to include('<li>')
        expect(html).to include('List item 1')
      end

      it 'renders ordered lists' do
        html = service.render_html
        expect(html).to include('<ol>')
        expect(html).to include('Numbered item')
      end

      it 'renders code blocks' do
        html = service.render_html
        expect(html).to include('<code')
        expect(html).to include('def hello')
      end

      it 'renders links' do
        html = service.render_html
        expect(html).to include('<a href')
        expect(html).to include('https://example.com')
      end

      it 'adds target="_blank" to links' do
        html = service.render_html
        expect(html).to include('target="_blank"')
      end
    end

    context 'with table markdown' do
      let(:markdown_source) do
        <<~MD
          | Header 1 | Header 2 | Header 3 |
          |----------|----------|----------|
          | Cell 1   | Cell 2   | Cell 3   |
          | Data A   | Data B   | Data C   |
        MD
      end
      let(:service) { described_class.new(markdown_source) }

      it 'renders table structure' do
        html = service.render_html
        expect(html).to include('<table>')
        expect(html).to include('<thead>')
        expect(html).to include('<tbody>')
        expect(html).to include('<tr>')
        expect(html).to include('<th>')
        expect(html).to include('<td>')
      end

      it 'includes table headers' do
        html = service.render_html
        expect(html).to include('Header 1')
        expect(html).to include('Header 2')
        expect(html).to include('Header 3')
      end

      it 'includes table data' do
        html = service.render_html
        expect(html).to include('Cell 1')
        expect(html).to include('Data A')
      end
    end

    context 'with strikethrough' do
      let(:service) { described_class.new('This is ~~deleted~~ text') }

      it 'renders strikethrough as del tag' do
        html = service.render_html
        expect(html).to include('<del>deleted</del>')
      end
    end

    context 'with superscript' do
      let(:service) { described_class.new('E = mc^2') }

      it 'renders superscript' do
        html = service.render_html
        expect(html).to include('<sup>2</sup>')
      end
    end

    context 'with highlight' do
      let(:service) { described_class.new('This is ==highlighted== text') }

      it 'renders highlighted text' do
        html = service.render_html
        expect(html).to include('<mark>highlighted</mark>')
      end
    end

    context 'with footnotes' do
      let(:markdown_source) do
        <<~MD
          This has a footnote[^1].

          [^1]: This is the footnote content.
        MD
      end
      let(:service) { described_class.new(markdown_source) }

      it 'renders footnotes' do
        html = service.render_html
        expect(html).to include('footnote')
      end
    end

    context 'with autolinks' do
      let(:service) { described_class.new('Visit https://example.com for more info') }

      it 'automatically converts URLs to links' do
        html = service.render_html
        expect(html).to include('<a href="https://example.com"')
      end
    end

    context 'with fenced code blocks' do
      let(:markdown_source) do
        <<~'MD'
          ```ruby
          def greet(name)
            puts "Hello, #{name}!"
          end
          ```
        MD
      end
      let(:service) { described_class.new(markdown_source) }

      it 'renders fenced code blocks' do
        html = service.render_html
        expect(html).to include('<code')
        expect(html).to include('def greet')
      end

      it 'includes language class for syntax highlighting' do
        html = service.render_html
        expect(html).to include('language-ruby')
      end
    end

    context 'with underline' do
      let(:service) { described_class.new('This is _underlined_ text') }

      it 'renders underline' do
        html = service.render_html
        expect(html).to include('<u>underlined</u>')
      end
    end

    context 'with custom options' do
      let(:markdown_source) { '# Title' }

      it 'accepts custom options' do
        custom_service = described_class.new(markdown_source, hard_wrap: false)
        expect { custom_service.render_html }.not_to raise_error
      end

      it 'merges custom options with defaults' do
        custom_service = described_class.new(markdown_source, filter_html: true)
        html = custom_service.render_html
        expect(html).to be_a(String)
      end
    end

    context 'with empty content' do
      let(:service) { described_class.new('') }

      it 'returns empty string for empty input' do
        expect(service.render_html).to eq('')
      end
    end

    context 'with nil content' do
      let(:service) { described_class.new(nil) }

      it 'handles nil gracefully' do
        expect { service.render_html }.not_to raise_error
      end
    end
  end

  describe '#render_plain_text' do
    context 'with basic markdown' do
      let(:service) { described_class.new('# Hello **World**') }

      it 'returns plain text without HTML tags' do
        plain = service.render_plain_text
        expect(plain).not_to match(/<[^>]+>/)
      end

      it 'includes text content' do
        plain = service.render_plain_text
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

          [Link](https://example.com)

          ```ruby
          code here
          ```
        MD
      end
      let(:service) { described_class.new(markdown_source) }

      it 'extracts all text content' do
        plain = service.render_plain_text
        expect(plain).to include('Title')
        expect(plain).to include('bold')
        expect(plain).to include('italic')
        expect(plain).to include('Item 1')
        expect(plain).to include('Item 2')
      end

      it 'removes HTML tags completely' do
        plain = service.render_plain_text
        expect(plain).not_to match(/<h1>/)
        expect(plain).not_to match(/<strong>/)
        expect(plain).not_to match(/<em>/)
        expect(plain).not_to match(/<ul>/)
        expect(plain).not_to match(/<li>/)
        expect(plain).not_to match(/<a[^>]*>/)
        expect(plain).not_to match(/<code>/)
      end

      it 'includes code content as plain text' do
        plain = service.render_plain_text
        expect(plain).to include('code here')
      end
    end

    context 'with tables' do
      let(:markdown_source) do
        <<~MD
          | Header | Data |
          |--------|------|
          | A      | 1    |
        MD
      end
      let(:service) { described_class.new(markdown_source) }

      it 'extracts table text content' do
        plain = service.render_plain_text
        expect(plain).to include('Header')
        expect(plain).to include('Data')
        expect(plain).to include('A')
        expect(plain).to include('1')
      end

      it 'removes table HTML tags' do
        plain = service.render_plain_text
        expect(plain).not_to match(/<table>/)
        expect(plain).not_to match(/<thead>/)
        expect(plain).not_to match(/<tbody>/)
        expect(plain).not_to match(/<tr>/)
        expect(plain).not_to match(/<th>/)
        expect(plain).not_to match(/<td>/)
      end
    end

    context 'with empty content' do
      let(:service) { described_class.new('') }

      it 'returns empty string for empty input' do
        expect(service.render_plain_text).to eq('')
      end
    end
  end

  describe 'default options' do
    let(:service) { described_class.new('# Test') }

    it 'enables autolink' do
      expect(service.send(:default_options)[:extensions][:autolink]).to be true
    end

    it 'enables tables' do
      expect(service.send(:default_options)[:extensions][:tables]).to be true
    end

    it 'enables fenced_code_blocks' do
      expect(service.send(:default_options)[:extensions][:fenced_code_blocks]).to be true
    end

    it 'enables strikethrough' do
      expect(service.send(:default_options)[:extensions][:strikethrough]).to be true
    end

    it 'enables superscript' do
      expect(service.send(:default_options)[:extensions][:superscript]).to be true
    end

    it 'enables highlight' do
      expect(service.send(:default_options)[:extensions][:highlight]).to be true
    end

    it 'enables footnotes' do
      expect(service.send(:default_options)[:extensions][:footnotes]).to be true
    end

    it 'enables underline' do
      expect(service.send(:default_options)[:extensions][:underline]).to be true
    end

    it 'disables filter_html by default' do
      expect(service.send(:default_options)[:render_options][:filter_html]).to be false
    end

    it 'enables hard_wrap' do
      expect(service.send(:default_options)[:render_options][:hard_wrap]).to be true
    end

    it 'enables with_toc_data' do
      expect(service.send(:default_options)[:render_options][:with_toc_data]).to be true
    end

    it 'enables prettify' do
      expect(service.send(:default_options)[:render_options][:prettify]).to be true
    end
  end

  describe 'integration with Content::Markdown model' do
    let(:markdown_block) do
      BetterTogether::Content::Markdown.new(markdown_source: '# Integration Test')
    end

    it 'is used by Content::Markdown#rendered_html' do
      expect(described_class).to receive(:new).with('# Integration Test', {}).and_call_original
      markdown_block.rendered_html
    end

    it 'is used by Content::Markdown#rendered_plain_text' do
      expect(described_class).to receive(:new).with('# Integration Test', {}).and_call_original
      markdown_block.rendered_plain_text
    end
  end

  describe 'mermaid diagram rendering' do
    context 'with mermaid code blocks' do
      let(:markdown_source) do
        <<~MD
          # Documentation

          ```mermaid
          graph TD
            A[Start] --> B[End]
          ```
        MD
      end
      let(:service) { described_class.new(markdown_source) }

      it 'renders mermaid code blocks with mermaid-diagram class' do
        html = service.render_html
        expect(html).to include('<pre class="mermaid-diagram">')
        expect(html).to include('graph TD')
        expect(html).to include('A[Start] --&gt; B[End]')
      end

      it 'does not wrap mermaid blocks in code tags' do
        html = service.render_html
        expect(html).not_to include('<code class="language-mermaid">')
      end

      it 'escapes HTML entities in mermaid content' do
        html = service.render_html
        expect(html).to include('--&gt;') # Arrow is escaped
      end
    end

    context 'with regular code blocks' do
      let(:markdown_source) do
        <<~MD
          ```ruby
          def hello
            puts "world"
          end
          ```
        MD
      end
      let(:service) { described_class.new(markdown_source) }

      it 'renders regular code blocks with code tags' do
        html = service.render_html
        expect(html).to include('<code')
        expect(html).to include('class="language-ruby"')
      end

      it 'does not add mermaid-diagram class to regular code blocks' do
        html = service.render_html
        expect(html).not_to include('class="mermaid-diagram"')
      end
    end

    context 'with multiple diagram types' do
      let(:markdown_source) do
        <<~MD
          # Mixed Content

          ```mermaid
          sequenceDiagram
            User->>Server: Request
          ```

          ```ruby
          puts "hello"
          ```

          ```mermaid
          graph LR
            A --> B
          ```
        MD
      end
      let(:service) { described_class.new(markdown_source) }

      it 'renders multiple mermaid diagrams correctly' do
        html = service.render_html
        expect(html.scan('<pre class="mermaid-diagram">').count).to eq(2)
      end

      it 'renders non-mermaid code blocks separately' do
        html = service.render_html
        expect(html).to include('class="language-ruby"')
      end
    end
  end
end
