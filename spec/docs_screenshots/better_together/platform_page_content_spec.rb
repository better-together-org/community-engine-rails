# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/platform_page_content_spec.rb
#
# Documents the header, footer and 404 headline fields and a 404 page using a headline set.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for platform page content', # rubocop:disable RSpec/SpecFilePathSuffix
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
  end

  after do
    host_platform.update!(page_content: {})
    Current.platform = nil
  end

  def capture_page(name, title, bullet, selector, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name,
      device: :both,
      metadata: { locale:, role: 'platform_manager', feature_set: 'platform_page_content',
                  flow: name, source_spec: self.class.metadata[:file_path] },
      callouts: [{ selector:, title:, bullets: [bullet], position: 'below' }],
      &
    )
  end

  it 'captures the content fields' do
    result = capture_page('platform_page_content_fields', 'Header, footer and 404',
                          'One headline per line; one is chosen at random.', '#platform-page-content-not-found-headlines') do
      capybara_login_as_platform_manager
      visit edit_platform_path(host_platform, locale:)
      find('#platform-appearance-tab').click
      expect(page).to have_css('#platform-page-content-settings', wait: 10)
      fill_in 'platform_page_content_not_found_headlines_en', with: "Lost in the woods\nNothing here but mushrooms"
      find('#platform-page-content-settings').scroll_to(:top)
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/platform_page_content_fields.png')
  end

  it 'captures a 404 page with a custom headline and header content' do
    host_platform.update!(page_content: { 'header_html' => { 'en' => '<p class="text-center m-0">Next foray: join us in September</p>' },
                                          'not_found_headlines' => { 'en' => 'Nothing here but mushrooms' } })
    result = capture_page('platform_page_content_404', 'Custom 404', 'The headline comes from the platform set.',
                          '#not-found-headline') do
      visit "/#{locale}/no-such-page-for-docs"
      expect(page).to have_css('#not-found-headline', text: 'Nothing here but mushrooms', wait: 10)
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/platform_page_content_404.png')
  end
end
