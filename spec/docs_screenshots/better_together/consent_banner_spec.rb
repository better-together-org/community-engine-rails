# frozen_string_literal: true

# Capture command (run from repo root):
#   bin/dc-run env RUN_DOCS_SCREENSHOTS=1 bundle exec rspec \
#     spec/docs_screenshots/better_together/consent_banner_spec.rb
#
# Documents the visitor consent banner with its choices open.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the consent banner', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot, :js, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let!(:host_platform) { configure_host_platform }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    BetterTogether::PlatformSnippet.create!(platform: host_platform, name: 'Stats', location: 'head_end',
                                            kind: 'script_inline', content: 'window.statsLoaded = true;',
                                            consent_category: 'analytics', enabled: true)
  end

  [false, true].each do |annotated|
    it "captures the banner#{' annotated' if annotated}" do
      name = "consent_banner#{'_annotated' if annotated}"
      callouts = if annotated
                   [{ selector: '#consent-choose', title: 'Choose', position: 'above',
                      bullets: ['Opens analytics and marketing choices.'] }]
                 else
                   []
                 end
      result = BetterTogether::CapybaraScreenshotEngine.capture(
        name,
        device: :both,
        metadata: { locale:, role: 'visitor', feature_set: 'consent', flow: 'consent_banner',
                    source_spec: self.class.metadata[:file_path] },
        callouts:
      ) do
        visit better_together.new_user_session_path(locale:)
        expect(page).to have_css('#consent-banner', wait: 10)
        find('#consent-choose').click
        expect(page).to have_css('#consent-choices', visible: :visible)
        # Full-page capture drops fixed elements, so show the banner in the page flow for the shot.
        page.execute_script("var b = document.getElementById('consent-banner'); b.style.position = 'static'; b.style.margin = '1rem auto'")
        find('#consent-banner').scroll_to(:center)
      end

      expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{name}.png")
    end
  end
end
