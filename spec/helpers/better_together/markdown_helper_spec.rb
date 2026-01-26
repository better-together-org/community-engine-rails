# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe MarkdownHelper do
    describe '#render_markdown' do
      context 'with basic markdown' do
        it 'renders markdown to HTML' do
          html = helper.render_markdown('# Hello World')

          expect(html).to include('<h1')
          expect(html).to include('Hello World')
        end

        it 'returns HTML-safe content' do
          html = helper.render_markdown('# Hello')

          expect(html).to be_html_safe
        end
      end

      context 'with complex markdown' do
        let(:markdown) do
          <<~MD
            # Title

            This is **bold** and *italic* text.

            - Item 1
            - Item 2

            [Link](https://example.com)
          MD
        end

        it 'renders all markdown features' do
          html = helper.render_markdown(markdown)

          expect(html).to include('<h1')
          expect(html).to include('<strong>bold</strong>')
          expect(html).to include('<em>italic</em>')
          expect(html).to include('<ul>')
          expect(html).to include('<li>Item 1</li>')
          expect(html).to include('<a href')
        end
      end

      context 'with custom options' do
        it 'accepts custom rendering options' do
          html = helper.render_markdown('# Test', hard_wrap: false)

          expect(html).to be_a(String)
          expect(html).to include('Test')
        end

        it 'passes options to MarkdownRendererService' do
          expect(MarkdownRendererService).to receive(:new)
            .with('# Test', { hard_wrap: false })
            .and_call_original

          helper.render_markdown('# Test', hard_wrap: false)
        end
      end

      context 'with empty or nil input' do
        it 'returns empty string for nil' do
          expect(helper.render_markdown(nil)).to eq('')
        end

        it 'returns empty string for empty string' do
          expect(helper.render_markdown('')).to eq('')
        end

        it 'returns empty string for whitespace-only string' do
          expect(helper.render_markdown('   ')).to eq('')
        end
      end
    end

    describe '#render_markdown_file' do
      let(:file_path) { Rails.root.join('spec/fixtures/files/test_helper.md') }
      let(:file_content) { "# Test File\n\nThis is from a file." }

      before do
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, file_content)
      end

      after do
        FileUtils.rm_f(file_path)
      end

      context 'with absolute path' do
        it 'reads and renders the file' do
          html = helper.render_markdown_file(file_path.to_s)

          expect(html).to include('<h1')
          expect(html).to include('Test File')
          expect(html).to include('This is from a file')
        end

        it 'returns HTML-safe content' do
          html = helper.render_markdown_file(file_path.to_s)

          expect(html).to be_html_safe
        end
      end

      context 'with relative path' do
        it 'resolves relative path from Rails.root' do
          html = helper.render_markdown_file('spec/fixtures/files/test_helper.md')

          expect(html).to include('Test File')
          expect(html).to include('This is from a file')
        end
      end

      context 'with custom options' do
        it 'passes options to render_markdown' do
          expect(helper).to receive(:render_markdown)
            .with(file_content, { hard_wrap: false })
            .and_call_original

          helper.render_markdown_file(file_path.to_s, hard_wrap: false)
        end
      end

      context 'with nonexistent file' do
        it 'returns empty string' do
          html = helper.render_markdown_file('/nonexistent/file.md')

          expect(html).to eq('')
        end

        it 'does not raise an exception' do
          expect do
            helper.render_markdown_file('/nonexistent/file.md')
          end.not_to raise_error
        end
      end

      context 'with empty or nil path' do
        it 'returns empty string for nil' do
          expect(helper.render_markdown_file(nil)).to eq('')
        end

        it 'returns empty string for empty string' do
          expect(helper.render_markdown_file('')).to eq('')
        end

        it 'returns empty string for whitespace-only string' do
          expect(helper.render_markdown_file('   ')).to eq('')
        end
      end
    end

    describe '#render_markdown_plain' do
      context 'with basic markdown' do
        it 'returns plain text without HTML tags' do
          plain = helper.render_markdown_plain('# Hello **World**')

          expect(plain).not_to match(/<[^>]+>/)
          expect(plain).to include('Hello')
          expect(plain).to include('World')
        end
      end

      context 'with complex markdown' do
        let(:markdown) do
          <<~MD
            # Title

            This is **bold** and *italic*.

            - Item 1
            - Item 2

            [Link](https://example.com)

            ```ruby
            code
            ```
          MD
        end

        it 'extracts all text content' do
          plain = helper.render_markdown_plain(markdown)

          expect(plain).to include('Title')
          expect(plain).to include('bold')
          expect(plain).to include('italic')
          expect(plain).to include('Item 1')
          expect(plain).to include('Item 2')
        end

        it 'removes all HTML tags' do
          plain = helper.render_markdown_plain(markdown)

          expect(plain).not_to match(/<[^>]+>/)
        end

        it 'includes code content as text' do
          plain = helper.render_markdown_plain(markdown)

          expect(plain).to include('code')
        end
      end

      context 'with custom options' do
        it 'accepts custom rendering options' do
          plain = helper.render_markdown_plain('# Test', hard_wrap: false)

          expect(plain).to be_a(String)
          expect(plain).to include('Test')
        end

        it 'passes options to MarkdownRendererService' do
          expect(MarkdownRendererService).to receive(:new)
            .with('# Test', { hard_wrap: false })
            .and_call_original

          helper.render_markdown_plain('# Test', hard_wrap: false)
        end
      end

      context 'with empty or nil input' do
        it 'returns empty string for nil' do
          expect(helper.render_markdown_plain(nil)).to eq('')
        end

        it 'returns empty string for empty string' do
          expect(helper.render_markdown_plain('')).to eq('')
        end

        it 'returns empty string for whitespace-only string' do
          expect(helper.render_markdown_plain('   ')).to eq('')
        end
      end
    end

    describe 'integration with views' do
      it 'can be used in views' do
        # Simulate view usage
        html = helper.render_markdown('# View Test')

        expect(html).to be_html_safe
        expect(html).to include('View Test')
      end

      it 'can render file content in views' do
        file_path = Rails.root.join('spec/fixtures/files/view_test.md')
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, '# View File Test')

        html = helper.render_markdown_file('spec/fixtures/files/view_test.md')

        expect(html).to include('View File Test')

        FileUtils.rm_f(file_path)
      end
    end
  end
end
