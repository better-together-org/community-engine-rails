# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::PagesController', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  describe 'GET /:locale/pages' do
    it 'renders index without N+1 on block string_translations' do
      pages = create_list(:better_together_page, 3, published_at: 1.day.ago, privacy: 'public')
      pages.each do |page|
        block = create(:content_markdown, markdown_source: '## Heading')
        page.page_blocks.create!(block:, position: 0)
      end

      get better_together.pages_path(locale:)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /:locale/pages/:slug' do
    let(:page) do
      create(:better_together_page,
             slug: 'test-page-spec',
             identifier: 'test-page-spec',
             protected: false,
             published_at: 1.day.ago,
             privacy: 'public')
    end

    before do
      block = create(:content_markdown, markdown_source: '## Content block')
      page.page_blocks.create!(block:, position: 0)
    end

    it 'renders show without N+1 on content block string_translations' do
      get better_together.page_path(page.slug, locale:)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /:locale/pages/:slug/edit' do
    let(:page) do
      create(:better_together_page,
             slug: 'test-page-edit-spec',
             identifier: 'test-page-edit-spec',
             protected: false,
             published_at: 1.day.ago)
    end

    before do
      block = create(:content_markdown, markdown_source: '## Editable content')
      page.page_blocks.create!(block:, position: 0)
    end

    it 'renders edit without N+1 on block string_translations' do
      get better_together.edit_page_path(page.slug, locale:)

      expect(response).to have_http_status(:ok)
    end
  end
end
