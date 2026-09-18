# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for JOATU GitHub contribution import browser', :docs_screenshot, :js, retry: 0, type: :feature do
  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'
  end

  it 'captures desktop and mobile screenshots for importing github contribution activity into a joatu request' do
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
           handle: 'joatu-maintainer',
           auth: {
             'citation_import_preview' => [
               {
                 'reference_key' => 'commit_joatu_governance',
                 'source_kind' => 'commit',
                 'title' => 'Harden JOATU contribution evidence surfaces',
                 'source_author' => 'joatu-maintainer',
                 'publisher' => 'GitHub',
                 'source_url' => 'https://github.com/better-together-org/community-engine-rails/commit/aab525784',
                 'locator' => 'aab525784',
                 'metadata' => {
                   'repository_name' => 'better-together-org/community-engine-rails',
                   'commit_sha' => 'aab525784',
                   'github_handle' => 'joatu-maintainer'
                 }
               }
             ]
           })

    request_record = create(:better_together_joatu_request,
                            creator: user.person,
                            name: 'GitHub-backed JOATU request',
                            privacy: 'private')

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'joatu_github_contribution_import_browser',
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        flow: 'joatu_github_contribution_import_browser',
        source_spec: self.class.metadata[:file_path]
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.edit_joatu_request_path(request_record, locale: I18n.default_locale)

      expect(page).to have_text('Import GitHub Contribution', wait: 10)
      all('summary', text: 'Import GitHub Contribution', minimum: 1).first.click
      click_button 'Load GitHub Contribution Sources'
      expect(page).to have_text('GitHub: @joatu-maintainer')
      expect(page).to have_text('commit_joatu_governance: Harden JOATU contribution evidence surfaces')
      expect(page).to have_text('Import Contribution')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/joatu_github_contribution_import_browser.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/joatu_github_contribution_import_browser.png')
  end
end
