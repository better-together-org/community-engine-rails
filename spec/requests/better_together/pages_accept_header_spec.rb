# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Static page Accept header negotiation', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:page) do
    slug = "accept-header-#{SecureRandom.hex(4)}"
    create(:better_together_page, slug:, identifier: slug, protected: false,
                                  published_at: 1.day.ago, privacy: 'public')
  end

  before do
    page.page_blocks.create!(block: create(:content_markdown, markdown_source: '## Hello'), position: 0)
  end

  {
    'text/html' => 'text/html',
    'a bare wildcard (curl, many crawlers)' => '*/*',
    'a browser-like list ending in a wildcard' => 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
    'a wildcard with a quality value' => '*/*;q=0.8'
  }.each do |label, accept|
    it "serves the page for Accept: #{label}" do
      get better_together.render_page_path(path: page.slug, locale:), headers: { 'Accept' => accept }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/html')
    end
  end

  it 'still refuses a JSON-only Accept header' do
    expect do
      get better_together.render_page_path(path: page.slug, locale:), headers: { 'Accept' => 'application/json' }
    end.to raise_error(ActionController::RoutingError)
  end
end
