# frozen_string_literal: true

# Capture command (run from repo root):
#   bin/dc-run bash -c "RUN_DOCS_SCREENSHOTS=1 bundle exec prspec \
#     spec/docs_screenshots/better_together/platform_redirects_admin_spec.rb"
#
# Documents the platform redirects admin: list, form and bulk import preview.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the redirects admin', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:host_platform) { configure_host_platform }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    create(:better_together_redirect, platform: host_platform, from_path: '/omphalina/xii-3.html',
                                      to_path: '/en/omphalina/xii-3', hit_count: 42)
    create(:better_together_redirect, platform: host_platform, from_path: '/pdf/Bylaws 2019.pdf',
                                      to_path: '/en/f/bylaws', status: 308)
    create(:better_together_redirect, :gone, platform: host_platform, from_path: '/forms/old-registration.html')
  end

  after { Current.platform = nil }

  def capture_redirects(name, flow:, callouts: [], &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name, device: :both, callouts:,
            metadata: { locale:, role: 'platform_manager', feature_set: 'platform_redirects', flow:,
                        source_spec: self.class.metadata[:file_path] }, &
    )
  end

  it 'captures the redirects list' do
    result = capture_redirects('platform_redirects_index', flow: 'redirects_index',
                                                           callouts: [{ selector: '#redirects-table', title: 'Redirects',
                                                                        bullets: ['Old path, new path, response and visits.'] }]) do
      capybara_login_as_platform_manager
      visit platform_redirects_path(host_platform, locale:)
      expect(page).to have_css('#redirects-table', wait: 10)
      find('#redirects-table').scroll_to(:center)
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/platform_redirects_index.png')
  end

  it 'captures the new redirect form' do
    result = capture_redirects('platform_redirects_form', flow: 'redirects_form',
                                                          callouts: [{ selector: '#redirect_status', title: 'Response',
                                                                       bullets: ['301, 302, 307, 308 or 410 Gone.'] }]) do
      capybara_login_as_platform_manager
      visit new_platform_redirect_path(host_platform, locale:)
      expect(page).to have_css('#redirect_from_path', wait: 10)
      find('#redirect_status').scroll_to(:center)
    end

    expect(result[:mobile]).to end_with('docs/screenshots/mobile/platform_redirects_form.png')
  end

  it 'captures the import preview' do
    result = capture_redirects('platform_redirects_import_preview', flow: 'redirects_import',
                                                                    callouts: [{ selector: '#redirects-import-report', title: 'Preview',
                                                                                 bullets: ['Nothing is saved until Import.'] }]) do
      capybara_login_as_platform_manager
      visit import_platform_redirects_path(host_platform, locale:)
      fill_in 'redirects_import_rows', with: "/a.html,/en/a\n/b.pdf,/en/f/b,308\n/bad,javascript:x"
      click_button 'redirects-import-preview-btn'
      expect(page).to have_css('#redirects-import-report', wait: 10)
      find('#redirects-import-report').scroll_to(:center)
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/platform_redirects_import_preview.png')
  end
end
