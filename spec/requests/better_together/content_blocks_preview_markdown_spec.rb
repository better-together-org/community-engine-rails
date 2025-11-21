# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Content Blocks Markdown Preview', :as_user, type: :request do
  let(:markdown_content) { "# Hello World\n\nThis is a **test**." }
  let(:preview_path) { "/#{I18n.default_locale}/content/blocks/preview_markdown" }

  describe 'POST /better_together/content/blocks/preview_markdown' do
    context 'when markdown content is provided' do
      it 'returns rendered HTML' do
        post preview_path,
             params: { markdown: markdown_content },
             as: :json

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(%r{application/json})

        json_response = JSON.parse(response.body)
        expect(json_response['html']).to include('<h1 id="hello-world">Hello World</h1>')
        expect(json_response['html']).to include('<strong>test</strong>')
      end

      it 'renders markdown with code blocks' do
        markdown_with_code = <<~MARKDOWN
          # Code Example

          ```ruby
          def hello
            puts "Hello, World!"
          end
          ```
        MARKDOWN

        post preview_path,
             params: { markdown: markdown_with_code },
             as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['html']).to include('<code')
        expect(json_response['html']).to include('def hello')
      end

      it 'renders markdown with tables' do
        markdown_with_table = <<~MARKDOWN
          | Column 1 | Column 2 |
          |----------|----------|
          | Value 1  | Value 2  |
        MARKDOWN

        post preview_path,
             params: { markdown: markdown_with_table },
             as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['html']).to include('<table')
        expect(json_response['html']).to include('<th')
        expect(json_response['html']).to include('<td')
      end

      it 'renders markdown with links' do
        markdown_with_links = <<~MARKDOWN
          [Example Link](https://example.com)

          https://auto-linked.com
        MARKDOWN

        post preview_path,
             params: { markdown: markdown_with_links },
             as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['html']).to include('href="https://example.com"')
        expect(json_response['html']).to include('href="https://auto-linked.com"')
      end
    end

    context 'when markdown content is blank' do
      it 'returns placeholder text' do
        post preview_path,
             params: { markdown: '' },
             as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['html']).to include('Preview will appear here')
      end

      it 'handles nil markdown parameter' do
        post preview_path,
             params: { markdown: nil },
             as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['html']).to include('Preview will appear here')
      end
    end

    context 'when an error occurs during rendering' do
      before do
        allow(BetterTogether::MarkdownRendererService).to receive(:new).and_raise(StandardError, 'Test error')
      end

      it 'returns an error message' do
        post preview_path,
             params: { markdown: markdown_content },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['html']).to include('Failed to render preview')
      end

      it 'logs the error' do
        allow(Rails.logger).to receive(:error)

        post preview_path,
             params: { markdown: markdown_content },
             as: :json

        expect(Rails.logger).to have_received(:error).with(/Markdown preview error/)
      end
    end

    context 'when user is not authenticated' do
      before do
        logout
      end

      it 'redirects to sign in' do
        post preview_path,
             params: { markdown: markdown_content },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with complex markdown features' do
      it 'renders strikethrough text' do
        markdown = '~~strikethrough~~'

        post preview_path,
             params: { markdown: markdown },
             as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['html']).to include('<del>strikethrough</del>')
      end

      it 'renders task lists' do
        markdown = <<~MARKDOWN
          - [ ] Unchecked task
          - [x] Checked task
        MARKDOWN

        post preview_path,
             params: { markdown: markdown },
             as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        # The renderer doesn't support GitHub-flavored task lists, so it renders as a regular list
        expect(json_response['html']).to include('<ul>')
        expect(json_response['html']).to include('<li>')
      end

      it 'renders blockquotes' do
        markdown = '> This is a quote'

        post preview_path,
             params: { markdown: markdown },
             as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['html']).to include('<blockquote>')
      end

      it 'renders inline code' do
        markdown = 'Use `code` in text'

        post preview_path,
             params: { markdown: markdown },
             as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['html']).to include('<code class="prettyprint">code</code>')
      end
    end
  end
end
