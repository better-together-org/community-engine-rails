# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pages title display', :as_platform_manager do
  describe 'GET /pages/:slug' do
    context 'when page has no hero block' do
      let(:page_without_hero) do
        create(:better_together_page,
               title: 'Page Without Hero',
               slug: 'aaa-page-without-hero',
               identifier: 'aaa-page-without-hero',
               protected: false,
               published_at: 1.day.ago)
      end

      before do
        # Add a non-hero block to ensure page renders
        markdown_block = create(:content_markdown, markdown_source: '## Test content')
        page_without_hero.page_blocks.create!(block: markdown_block, position: 0)
      end

      it 'displays the page title as an h1' do
        get better_together.page_path(page_without_hero.slug, locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('<h1 class="page-title">Page Without Hero</h1>')
      end

      it 'includes the page title in a container div' do
        get better_together.page_path(page_without_hero.slug, locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('<div class="container my-4">')
        expect(response.body).to match(%r{<div class="container my-4">.*<h1 class="page-title">Page Without Hero</h1>.*</div>}m)
      end
    end

    context 'when page has a hero block' do
      let(:page_with_hero) do
        create(:better_together_page,
               title: 'Page With Hero',
               slug: 'aaa-page-with-hero',
               identifier: 'aaa-page-with-hero',
               protected: false,
               published_at: 1.day.ago)
      end

      before do
        # Add a hero block to the page
        hero_block = create(:content_hero,
                            title: 'Hero Title',
                            subtitle: 'Hero Subtitle')
        page_with_hero.page_blocks.create!(block: hero_block, position: 0)
      end

      it 'does not display the page title as an h1' do
        get better_together.page_path(page_with_hero.slug, locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('<h1 class="page-title">Page With Hero</h1>')
      end

      it 'renders the hero block instead' do
        get better_together.page_path(page_with_hero.slug, locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        # Hero blocks have their own title rendering
        expect(response.body).to include('Hero Title')
        expect(response.body).to include('Hero Subtitle')
      end
    end

    context 'when page has template and no content blocks' do
      let(:page_with_template) do
        create(:better_together_page,
               title: 'Page With Template',
               slug: 'aaa-page-with-template',
               identifier: 'aaa-page-with-template',
               protected: false,
               published_at: 1.day.ago,
               template: 'better_together/static_pages/better_together')
      end

      it 'does not display the page title as an h1' do
        get better_together.page_path(page_with_template.slug, locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        # Template pages handle their own title rendering
        expect(response.body).not_to include('<h1 class="page-title">Page With Template</h1>')
      end
    end

    context 'when page has multiple blocks but no hero' do
      let(:page_with_multiple_blocks) do
        create(:better_together_page,
               title: 'Multi Block Page',
               slug: 'aaa-multi-block-page',
               identifier: 'aaa-multi-block-page',
               protected: false,
               published_at: 1.day.ago)
      end

      before do
        # Add multiple non-hero blocks
        markdown_block1 = create(:content_markdown, markdown_source: '## First section')
        markdown_block2 = create(:content_markdown, markdown_source: '## Second section')
        page_with_multiple_blocks.page_blocks.create!(block: markdown_block1, position: 0)
        page_with_multiple_blocks.page_blocks.create!(block: markdown_block2, position: 1)
      end

      it 'displays the page title as an h1 before the content' do
        get better_together.page_path(page_with_multiple_blocks.slug, locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('<h1 class="page-title">Multi Block Page</h1>')

        # Verify title appears before content
        title_position = response.body.index('<h1 class="page-title">Multi Block Page</h1>')
        content_position = response.body.index('First section')
        expect(title_position).to be < content_position
      end
    end

    context 'when page title contains HTML-sensitive characters' do
      let(:page_with_special_chars) do
        create(:better_together_page,
               title: 'Page & Title <with> "Special" Characters',
               slug: 'aaa-page-special-chars',
               identifier: 'aaa-page-special-chars',
               protected: false,
               published_at: 1.day.ago)
      end

      before do
        markdown_block = create(:content_markdown, markdown_source: '## Test content')
        page_with_special_chars.page_blocks.create!(block: markdown_block, position: 0)
      end

      it 'properly escapes the title' do
        get better_together.page_path(page_with_special_chars.slug, locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Page &amp; Title &lt;with&gt; &quot;Special&quot; Characters')
        expect(response.body).not_to include('Page & Title <with> "Special" Characters')
      end
    end
  end
end
