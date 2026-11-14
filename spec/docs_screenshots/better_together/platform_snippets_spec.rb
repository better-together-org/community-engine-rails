# frozen_string_literal: true

# Capture command (run from repo root):
#   bin/dc-run env RUN_DOCS_SCREENSHOTS=1 bundle exec rspec \
#     spec/docs_screenshots/better_together/platform_snippets_spec.rb
#
# Documents the custom code admin: the snippet list with its kill switch and audit trail, and the form.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for platform custom code', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:host_platform) { configure_host_platform }

  pages = {
    'index' => ['#platform-snippets-kill-switch', 'Kill switch and audit trail',
                'Switch every snippet off at once; recent changes are listed below.'],
    'form' => ['#platform_snippet_enabled', 'New snippets start disabled',
               'Test with safe mode, then enable.']
  }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  pages.each do |page_name, (selector, title, bullet)|
    [false, true].each do |annotated|
      it "captures the #{page_name} page#{' annotated' if annotated}" do
        name = "platform_snippets_#{page_name}#{'_annotated' if annotated}"
        callouts = annotated ? [{ selector:, title:, bullets: [bullet], position: 'below' }] : []
        result = BetterTogether::CapybaraScreenshotEngine.capture(
          name,
          device: :both,
          metadata: {
            locale:, role: 'platform_code_manager', feature_set: 'platform_snippets',
            flow: "platform_snippets_#{page_name}", source_spec: self.class.metadata[:file_path]
          },
          callouts:
        ) do
          capybara_login_as_platform_manager
          person = BetterTogether::User.find_by!(email: 'manager@example.test').person
          host_platform.person_platform_memberships.find_or_create_by!(
            member: person, role: BetterTogether::Role.find_by!(identifier: 'platform_code_manager'), status: 'active'
          )
          BetterTogether::PlatformSnippet.find_or_create_by!(platform: host_platform, name: 'Example tracker') do |s|
            s.assign_attributes(location: 'head_end', kind: 'script_inline', content: 'window.example = true;')
          end
          person.expire_permission_cache!
          visit(if page_name == 'index'
                  platform_platform_snippets_path(host_platform, locale:)
                else
                  new_platform_platform_snippet_path(host_platform, locale:)
                end)
          expect(page).to have_css(selector, wait: 10)
          expect(page).to be_axe_clean.within('main').according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
          find(selector).scroll_to(:center)
        end

        expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{name}.png")
      end
    end
  end
end
