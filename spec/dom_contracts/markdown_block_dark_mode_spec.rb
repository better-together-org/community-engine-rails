# frozen_string_literal: true

require 'rails_helper'

# Markdown block styling keys off these hooks; dark mode colours come from Bootstrap variables, not from them.
RSpec.describe 'Markdown block dark mode DOM contract', type: :request do
  include RequestSpecHelper

  let!(:host_platform) { configure_host_platform }
  let(:page_record) do
    create(:better_together_page, title: 'Dark mode page', slug: 'dark-mode-page', identifier: 'dark-mode-page',
                                  platform: host_platform, protected: false, privacy: 'public', published_at: 1.day.ago)
  end

  before do
    page_record.page_blocks.create!(block: create(:content_markdown, markdown_source: "## Heading\n\nBody text"), position: 0)
    get better_together.render_page_path(path: page_record.slug, locale: I18n.default_locale)
  end

  it 'renders the markdown content hook inside its block and the colour mode attribute on html', :aggregate_failures do
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-block-type="markdown"')
    expect(response.body).to include('class="markdown-content"')
    expect(response.body).to match(/<html[^>]*data-bts-color-mode=/)
  end
end
