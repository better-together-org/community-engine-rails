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
      slug = "test-page-spec-#{SecureRandom.hex(4)}"
      create(:better_together_page,
             slug:,
             identifier: slug,
             protected: false,
             published_at: 1.day.ago,
             privacy: 'public')
    end
    let(:block) { create(:content_markdown, markdown_source: '## Content block') }

    before do
      page.page_blocks.create!(block:, position: 0)
    end

    it 'renders show without N+1 on content block string_translations' do
      get better_together.page_path(page.slug, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-evidence-selector="block:markdown:')
    end

    it 'renders shared content actions for reportable blocks inside the block wrapper' do
      get better_together.page_path(page.slug, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('bt-content-block__actions')
      expect(response.body).to include("reportable_id=#{block.id}")
      expect(response.body).to include('reportable_type=BetterTogether%3A%3AContent%3A%3ABlock')
    end

    it 'renders a bibliography for structured citations' do
      create(:better_together_citation,
             citeable: page,
             title: 'Page Evidence Record',
             reference_key: 'page_evidence_record')

      get better_together.page_path(page.slug, locale:)

      expect(response.body).to include('Evidence and Citations')
      expect(response.body).to include('Page Evidence Record')
      expect(response.body).to include('citation-page_evidence_record')
    end

    it 'renders claims and supporting evidence when present' do
      citation = create(:better_together_citation,
                        citeable: page,
                        title: 'Claim Support Record',
                        reference_key: 'claim_support_record')
      claim = create(:better_together_claim,
                     claimable: page,
                     claim_key: 'supported_publication_claim',
                     statement: 'Public claims should stay tied to auditable evidence.')
      create(:better_together_evidence_link,
             claim:,
             citation:,
             relation_type: 'supports',
             locator: 'p. 3')

      get better_together.page_path(page.slug, locale:)

      expect(response.body).to include('Claims and Supporting Evidence')
      expect(response.body).to include('Public claims should stay tied to auditable evidence.')
      expect(response.body).to include('Claim Support Record')
      expect(response.body).to include('claim-supported_publication_claim')
    end

    context 'when the page contains a Content::Template block (no string_translations association)' do
      before do
        # Content::Template has no Mobility string attributes — it must not raise
        # AssociationNotFoundError when preloading string_translations on mixed block types.
        template_block = create(:content_template)
        page.page_blocks.create!(block: template_block, position: 1)
      end

      it 'renders without AssociationNotFoundError' do
        get better_together.page_path(page.slug, locale:)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'GET /:locale/pages/:slug/edit' do
    let(:page) do
      slug = "test-page-edit-spec-#{SecureRandom.hex(4)}"
      create(:better_together_page,
             slug:,
             identifier: slug,
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
