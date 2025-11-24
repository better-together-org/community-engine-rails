# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Markdown pages' do
  let(:page) do
    create(
      :better_together_page,
      title: 'Markdown Page',
      slug: 'markdown-page',
      privacy: 'public',
      published_at: Time.zone.now
    )
  end

  let(:page_path) { "/#{I18n.default_locale}/#{page.slug}" }

  describe 'GET /:locale/:path' do
    let(:markdown_content) { "# Markdown Heading\n\nThis is **bold** content for the page." }
    let(:markdown_block) { create(:content_markdown, markdown_source: markdown_content) }
    let!(:page_block) { BetterTogether::Content::PageBlock.create!(page:, block: markdown_block, position: 0) }

    it 'renders markdown blocks as HTML on the page' do
      get page_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<h1')
      expect(response.body).to include('Markdown Heading')
      expect(response.body).to include('<strong>bold</strong>')
      expect(response.body).not_to include('# Markdown Heading')
    end

    context 'when markdown content is loaded from a file' do
      let(:markdown_file_path) { Rails.root.join('spec/fixtures/files/page_markdown_render.md') }
      let(:markdown_block) do
        FileUtils.mkdir_p(markdown_file_path.dirname)
        File.write(markdown_file_path, "# File Heading\n\nFile paragraph with **formatting**.")

        create(:content_markdown, markdown_source: nil, markdown_file_path: markdown_file_path.to_s)
      end

      after do
        FileUtils.rm_f(markdown_file_path)
      end

      it 'renders the file-backed markdown content' do
        get page_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('File Heading')
        expect(response.body).to include('<strong>formatting</strong>')
        expect(response.body).not_to include(markdown_file_path.to_s)
      end
    end
  end
end
