# frozen_string_literal: true

# Capture command (run from repo root):
#   bin/dc-run env RUN_DOCS_SCREENSHOTS=1 bundle exec rspec \
#     spec/docs_screenshots/better_together/user_cookie_consent_spec.rb
#
# Documents the cookie consent tab in a person's settings and the extensible cookie policy page.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for user cookie consent', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot, :js, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include AutomaticTestConfiguration

  let(:locale) { I18n.default_locale }
  let!(:host_platform) { configure_host_platform }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    BetterTogether.register_consent_provider(:google_analytics) { :analytics }
    BetterTogether.register_cookie_policy_segment(
      :google_analytics, category: :analytics, title: 'Google Analytics',
                         description: 'Counts visits so the platform can see which pages help people.',
                         cookies: [{ name: '_ga', purpose: 'Tells one visitor from another', duration: '2 years',
                                     provider: 'Google', party: :third }],
                         privacy_url: 'https://policies.google.com/privacy', updated_on: Date.new(2026, 11, 14)
    )
    BetterTogether.register_consent_provider(:host_ads) { :marketing }
    BetterTogether.register_cookie_policy_segment(
      :host_ads, category: :marketing, title: 'Newsletter sign-up tracking',
                 description: 'Measures which pages lead to newsletter sign-ups.',
                 cookies: [{ name: 'nl_ref', purpose: 'Remembers the page that referred you', duration: '30 days',
                             party: :first }]
    )
  end

  after { BetterTogether::Consent.reset! }

  [false, true].each do |annotated|
    it "captures the settings tab#{' annotated' if annotated}" do
      name = "user_cookie_consent_settings#{'_annotated' if annotated}"
      callouts = if annotated
                   [{ selector: '#cookie-consent-settings', title: 'Your choices', position: 'below',
                      bullets: ['Saved to your account and applied on every visit.',
                                'Withdraw all turns every optional category off.'] }]
                 else
                   []
                 end
      result = BetterTogether::CapybaraScreenshotEngine.capture(
        name, device: :both,
              metadata: { locale:, role: 'user', feature_set: 'consent', flow: 'user_cookie_consent',
                          source_spec: self.class.metadata[:file_path] },
              callouts:
      ) do
        find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user)
        capybara_login_as_user
        visit better_together.settings_path(locale:)
        find('#cookie-consent-tab').click
        expect(page).to have_css('#cookie-consent-form', visible: :visible, wait: 10)
        find('#cookie-consent-fieldset').scroll_to(:center)
      end

      expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{name}.png")
    end
  end

  # Second pass over the same flags keeps each capture independent.
  [false, true].each do |annotated| # rubocop:disable Style/CombinableLoops
    it "captures the cookie policy table#{' annotated' if annotated}" do
      BetterTogether::NavigationBuilder.build(clear: false)
      page_record = BetterTogether::Page.i18n.find_by!(slug: 'cookie-policy')

      name = "cookie_policy_extensions#{'_annotated' if annotated}"
      callouts = if annotated
                   [{ selector: '#cookie-policy-category-analytics', title: 'From the registry', position: 'below',
                      bullets: ['Added by the extension, no policy text edited.'] }]
                 else
                   []
                 end
      result = BetterTogether::CapybaraScreenshotEngine.capture(
        name, device: :both,
              metadata: { locale:, role: 'visitor', feature_set: 'consent', flow: 'cookie_policy_extensions',
                          source_spec: self.class.metadata[:file_path] },
              callouts:
      ) do
        visit better_together.render_page_path(page_record.slug, locale:)
        expect(page).to have_css('#cookie-policy-category-analytics', wait: 10)
        page.execute_script("document.getElementById('cookie-policy-category-analytics').scrollIntoView({ block: 'start' })")
        sleep 0.5
      end

      expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{name}.png")
    end
  end
end
