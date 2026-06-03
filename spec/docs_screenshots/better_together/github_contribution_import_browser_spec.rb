# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for GitHub contribution import browser', :docs_screenshot, :js, retry: 0, type: :feature do
  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'
  end

  it 'captures desktop and mobile screenshots for importing github contribution activity into a page' do
    github_platform = BetterTogether::Platform.external.find_or_create_by!(identifier: 'github') do |platform|
      platform.name = 'GitHub'
      platform.url = 'https://github.com'
      platform.description = 'GitHub OAuth Provider'
      platform.time_zone = 'UTC'
      platform.privacy = :public
      platform.host = false
    end

    user = BetterTogether::User.find_by(email: 'manager@example.test') ||
           create(:user, :platform_manager, email: 'manager@example.test', password: 'SecureTest123!@#')

    create(:person_platform_integration,
           :github,
           user:,
           person: user.person,
           platform: github_platform,
           handle: 'evidence-maintainer',
           auth: {
             'citation_import_preview' => [
               {
                 'reference_key' => 'pull_request_1494',
                 'source_kind' => 'pull_request',
                 'title' => 'Governed publishing and evidence chain',
                 'source_author' => 'evidence-maintainer',
                 'publisher' => 'GitHub',
                 'source_url' => 'https://github.com/better-together-org/community-engine-rails/pull/1494',
                 'locator' => 'PR #1494',
                 'metadata' => {
                   'repository_name' => 'better-together-org/community-engine-rails',
                   'pull_request_number' => 1494,
                   'github_handle' => 'evidence-maintainer'
                 }
               }
             ]
           })

    page_record = create(:better_together_page,
                         slug: "github-contribution-import-browser-#{SecureRandom.hex(4)}",
                         identifier: "github-contribution-import-browser-#{SecureRandom.hex(4)}",
                         protected: false)

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'github_contribution_import_browser',
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        flow: 'github_contribution_import_browser',
        source_spec: self.class.metadata[:file_path]
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.edit_page_path(page_record.slug, locale: I18n.default_locale)

      expect(page).to have_text('Import GitHub Contribution', wait: 10)
      all('summary', text: 'Import GitHub Contribution', minimum: 1).first.click
      click_button 'Load GitHub Contribution Sources'
      expect(page).to have_text('GitHub: @evidence-maintainer')
      expect(page).to have_text('pull_request_1494: Governed publishing and evidence chain')
      expect(page).to have_text('Import Contribution')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/github_contribution_import_browser.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/github_contribution_import_browser.png')
  end
end
