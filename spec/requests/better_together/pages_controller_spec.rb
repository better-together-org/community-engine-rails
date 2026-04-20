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

    it 'renders the legacy block actions menu and the page feedback bar' do
      get better_together.page_path(page.slug, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('bt-content-block__actions')
      expect(response.body).to include('bt-content-actions__trigger')
      expect(response.body).to include("reportable_id=#{block.id}")
      expect(response.body).to include('reportable_type=BetterTogether%3A%3AContent%3A%3ABlock')
      expect(response.body).to include('bt-page-feedback-bar')
      expect(response.body).to include("reportable_id=#{page.id}")
    end

    it 'keeps bibliography out of the public page view' do
      create(:better_together_citation,
             citeable: page,
             title: 'Page Evidence Record',
             reference_key: 'page_evidence_record')

      get better_together.page_path(page.slug, locale:)

      expect(response.body).not_to include('Evidence and Citations')
      expect(response.body).not_to include('Page Evidence Record')
      expect(response.body).not_to include('citation-page_evidence_record')
    end

    it 'keeps the governed page byline visible while broader evidence UI stays hidden' do
      robot = create(:better_together_robot,
                     platform: page.platform,
                     name: 'BTS Publishing Robot',
                     identifier: "bts-page-robot-#{SecureRandom.hex(4)}")

      page.authorships.destroy_all
      page.authorships.create!(author: robot)

      get better_together.page_path(page.slug, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('BTS Publishing Robot')
      expect(response.body).to include('Robot')
      expect(response.body).not_to include('Contributors:')
      expect(response.body).not_to include('GitHub-linked')
    end

    it 'keeps claims and supporting evidence out of the public page view' do
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

      expect(response.body).not_to include('Claims and Supporting Evidence')
      expect(response.body).not_to include('Public claims should stay tied to auditable evidence.')
      expect(response.body).not_to include('Claim Support Record')
      expect(response.body).not_to include('claim-supported_publication_claim')
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

    context 'when the page mixes markdown and collection-backed blocks' do
      before do
        create(:better_together_post, published_at: 1.day.ago, platform: page.platform, title: 'Rendered News Post')
        page.page_blocks.create!(block: create(:content_posts_block), position: 1)
      end

      it 'renders without leaking collection locals between block partials' do
        get better_together.page_path(page.slug, locale:)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Rendered News Post')
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

    it 'renders the unified governed contributions form section' do
      page.add_governed_contributor(create(:better_together_person, name: 'Page Editor'), role: 'editor')

      get better_together.edit_page_path(page.slug, locale:)

      expect(response).to have_http_status(:ok)
      doc = Nokogiri::HTML.parse(response.body)
      section = doc.at_css('[data-controller="better_together--contribution-assignments"]')
      container = doc.at_css('[data-better_together--contribution-assignments-target="container"].row.g-3')
      entry = doc.at_css('[data-better_together--contribution-assignments-target="entry"].col-12.col-lg-6.nested-fields')

      expect(section).to be_present
      expect(container).to be_present
      expect(entry).to be_present
      expect(response.body).to include('page[contributions_attributes]')
      expect(response.body).not_to include('page[author_ids]')
      expect(response.body).not_to include('page[editor_ids]')
    end

    it 'renders the contributor display visibility field' do
      get better_together.edit_page_path(page.slug, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('page[contributors_display_visibility]')
    end
  end

  describe 'manager CRUD flows' do
    let(:page) do
      create(:better_together_page,
             :private,
             protected: false,
             title: 'Coverage Source Page',
             content: 'Initial content')
    end

    it 'creates a private page' do
      expect do
        post better_together.pages_path(locale:), params: {
          page: {
            title_en: 'Coverage Created Page',
            content_en: 'Created during CRUD coverage',
            privacy: 'private',
            show_title: true
          }
        }
      end.to change(BetterTogether::Page, :count).by(1)

      created_page = BetterTogether::Page.order(:created_at).last

      expect(response).to be_redirect
      expect(created_page.title).to eq('Coverage Created Page')
      expect(created_page.content.to_plain_text).to include('Created during CRUD coverage')
      expect(created_page.privacy).to eq('private')
    end

    it 'renders new when create params are invalid' do
      expect do
        post better_together.pages_path(locale:), params: {
          page: {
            title_en: '',
            content_en: '',
            privacy: 'private'
          }
        }
      end.not_to change(BetterTogether::Page, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'updates an existing page' do
      patch better_together.page_path(page, locale:), params: {
        page: {
          title_en: 'Updated Coverage Page',
          content_en: 'Updated coverage body'
        }
      }

      expect(response).to be_redirect
      expect(page.reload.title).to eq('Updated Coverage Page')
      expect(page.content.to_plain_text).to include('Updated coverage body')
    end

    it 'renders edit when update params are invalid' do
      patch better_together.page_path(page, locale:), params: {
        page: {
          title_en: '',
          content_en: ''
        }
      }

      expect(response).to have_http_status(:ok)
      expect(page.reload.title).to eq('Coverage Source Page')
    end

    it 'destroys an unprotected page' do
      delete better_together.page_path(page, locale:)

      expect(response).to be_redirect
      expect(BetterTogether::Page.exists?(page.id)).to be(false)
    end
  end
end
