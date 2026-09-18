# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for claim evidence browser', :docs_screenshot, :js, retry: 0, type: :feature do
  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'
  end

  it 'captures desktop and mobile screenshots for the page claim evidence browser' do
    page_record = create(:better_together_page,
                         slug: "claim-evidence-browser-#{SecureRandom.hex(4)}",
                         identifier: "claim-evidence-browser-#{SecureRandom.hex(4)}",
                         protected: false)

    create(:citation,
           citeable: page_record,
           reference_key: 'local_record',
           title: 'Local Record Citation',
           locator: 'p. 10',
           excerpt: 'Shared reality requires traceable evidence.')

    contributor = create(:person, name: 'Consensus Reviewer')
    contribution = BetterTogether::Authorship.create!(
      authorable: page_record,
      author: contributor,
      role: 'reviewer',
      contribution_type: 'documentation'
    )
    create(:citation,
           citeable: contribution,
           reference_key: 'review_notes',
           title: 'Review Notes',
           locator: 'p. 11',
           excerpt: 'Reviewed and verified against contribution notes.')

    github_platform = BetterTogether::Platform.external.find_or_create_by!(identifier: 'github') do |platform|
      platform.name = 'GitHub'
      platform.url = 'https://github.com'
      platform.description = 'GitHub OAuth Provider'
      platform.time_zone = 'UTC'
      platform.privacy = :public
      platform.host = false
    end

    manager = BetterTogether::User.find_by(email: 'manager@example.test') ||
              create(:user, :platform_manager, email: 'manager@example.test', password: 'SecureTest123!@#')
    create(:person_platform_integration,
           :github,
           user: manager,
           person: manager.person,
           platform: github_platform,
           handle: 'evidence-maintainer',
           auth: {
             'citation_import_preview' => [
               {
                 'reference_key' => 'commit_governance_bundle_links',
                 'source_kind' => 'commit',
                 'title' => 'Add governance bundle links'
               }
             ]
           })

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'claim_evidence_browser',
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        flow: 'claim_evidence_browser',
        source_spec: self.class.metadata[:file_path]
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.edit_page_path(page_record.slug, locale: I18n.default_locale)

      expect(page).to have_text('Claims and Supporting Evidence', wait: 10)
      all('summary', text: 'Browse Evidence Sources', minimum: 1).first.click
      expect(page).to have_text('Source Origin')
      expect(page).to have_text('Consensus Reviewer: Reviewer')
      all('summary', text: 'Import GitHub Evidence', minimum: 1).first.click
      expect(page).to have_button('Load GitHub Evidence')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/claim_evidence_browser.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/claim_evidence_browser.png')
  end
end
