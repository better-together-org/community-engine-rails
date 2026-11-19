# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the site-wide landmarks: skip link, banner, labelled navs and the main target.
RSpec.describe 'Site landmarks DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }
  let(:page_record) do
    slug = "landmarks-#{SecureRandom.hex(4)}"
    create(:better_together_page, slug:, identifier: slug, protected: false, published_at: 1.day.ago, privacy: 'public')
  end
  let(:doc) do
    page_record.page_blocks.create!(block: create(:content_markdown, markdown_source: '## Hello'), position: 0)
    get better_together.render_page_path(path: page_record.slug, locale:)
    Nokogiri::HTML(response.body)
  end

  it 'renders a skip link as the first focusable element, targeting the main landmark' do
    link = doc.at_css('a#skip-to-content')

    expect(link['href']).to eq('#main-content')
    expect(link.text.strip).to eq(I18n.t('navbar.skip_to_content', locale:))
    expect(doc.at_css('main#main-content')).to be_present
  end

  it 'wraps the site navigation in a header banner' do
    expect(doc.at_css('header#main-nav')).to be_present
  end

  it 'gives every site-level nav an accessible name' do
    %w[top-nav header-nav footer-pages-nav footer-platform-nav].each do |id|
      expect(doc.at_css("nav##{id}")&.[]('aria-label')).to be_present, "nav##{id} has no aria-label"
    end
  end

  it 'points the footer toggler at its own collapse' do
    toggler = doc.at_css('#footer-pages-nav .navbar-toggler')

    expect(toggler['aria-controls']).to eq('footerNavbarNavDropdown')
    expect(doc.at_css('#footerNavbarNavDropdown')).to be_present
  end

  it 'names the search toggle and the search field' do
    expect(doc.at_css("#top-nav a[href='#search']")['aria-label']).to be_present
    expect(doc.at_css('label[for=q]')).to be_present
  end

  it 'never emits the inert data-aria-expanded attribute' do
    expect(response.body).not_to include('data-aria-expanded')
  end
end
