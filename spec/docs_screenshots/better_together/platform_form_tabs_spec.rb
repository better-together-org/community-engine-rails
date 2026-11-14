# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/platform_form_tabs_spec.rb
#
# Documents the tabbed platform edit form: one capture per tab, desktop and mobile.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the tabbed platform form', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:host_platform) { configure_host_platform }

  tabs = {
    'details' => ['Details tab', 'Name, description, URL and time zone.'],
    'access' => ['Access and privacy tab', 'Who can see the platform and how people join.'],
    'appearance' => ['Appearance tab', 'Custom CSS today; theme settings land here next.'],
    'domains' => ['Domains and sign-in tab', 'Links to the platform domains and sign-in providers.'],
    'security' => ['Security tab', 'Content security policy origins.'],
    'features' => ['Features and quotas tab', 'Rollout gates and quota defaults.']
  }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  tabs.each do |tab, (title, bullet)|
    [false, true].each do |annotated|
      it "captures the #{tab} tab#{' annotated' if annotated}" do
        name = "platform_form_tab_#{tab}#{'_annotated' if annotated}"
        callouts = annotated ? [{ selector: "#platform-#{tab}-tab", title:, bullets: [bullet], position: 'below' }] : []
        result = BetterTogether::CapybaraScreenshotEngine.capture(
          name,
          device: :both,
          metadata: {
            locale:, role: 'platform_manager', feature_set: 'platform_form_tabs',
            flow: "platform_edit_#{tab}", source_spec: self.class.metadata[:file_path]
          },
          callouts:
        ) do
          capybara_login_as_platform_manager
          visit edit_platform_path(host_platform, locale:)
          find("#platform-#{tab}-tab").click
          expect(page).to have_css("#platform-#{tab}.show.active", wait: 10)
          find("#platform-#{tab}-tab").scroll_to(:center)
        end

        expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{name}.png")
        expect(result[:mobile]).to end_with("docs/screenshots/mobile/#{name}.png")
      end
    end
  end
end
