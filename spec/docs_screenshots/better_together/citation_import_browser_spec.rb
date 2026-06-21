# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for citation import browser', :docs_screenshot, :js, retry: 0, type: :feature do
  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'
  end

  it 'captures desktop and mobile screenshots for importing linked citations into a page' do
    page_record = create(:better_together_page,
                         slug: "citation-import-browser-#{SecureRandom.hex(4)}",
                         identifier: "citation-import-browser-#{SecureRandom.hex(4)}",
                         protected: false)

    contributor = create(:person, name: 'Citation Import Reviewer')
    contribution = BetterTogether::Authorship.create!(
      authorable: page_record,
      author: contributor,
      role: 'reviewer',
      contribution_type: 'documentation'
    )
    create(:citation,
           citeable: contribution,
           reference_key: 'review_import_notes',
           title: 'Review Import Notes',
           locator: 'p. 12',
           excerpt: 'Import this into the page bibliography for inline anchor support.')

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'citation_import_browser',
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        flow: 'citation_import_browser',
        source_spec: self.class.metadata[:file_path]
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.edit_page_path(page_record.slug, locale: I18n.default_locale)

      expect(page).to have_text('Citations and Evidence', wait: 10)
      all('summary', text: 'Import Linked Citation Into This Record', minimum: 1).first.click
      expect(page).to have_text('Citation Import Reviewer: Reviewer')
      expect(page).to have_text('Import Citation')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/citation_import_browser.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/citation_import_browser.png')
  end
end
