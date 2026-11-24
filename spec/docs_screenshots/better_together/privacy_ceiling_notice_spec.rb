# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/privacy_ceiling_notice_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/privacy_ceiling_notice.{png,json,narrative.yml}

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the privacy ceiling notice',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include ActionView::RecordIdentifier

  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'private', requires_invitation: false) }
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  it 'captures the notice beside the privacy select on the page form' do
    host_page = create(:better_together_page, platform: host_platform, title: 'Opening day', privacy: 'public')
    notice = "##{dom_id(host_page, :privacy_ceiling_notice)}"
    callouts = [{ id: 'notice', selector: notice, title: 'Visibility notice',
                  bullets: ['Saves as public, goes live when the platform opens.'] }]
    narrative = { title: 'Preparing public pages behind a private platform', audience: %w[host_admin],
                  journey_step: 'As a platform manager, I can prepare a public page before the platform is public.',
                  callouts: [{ id: 'notice', title: 'Visibility notice',
                               description: 'Explains who can see the page today.' }],
                  accessibility_notes: 'The notice is a labelled note linked to the select, with a decorative icon.' }
    metadata = { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'privacy_ceiling_notice',
                 flow: 'privacy_ceiling_notice', source_spec: self.class.metadata[:file_path] }

    BetterTogether::CapybaraScreenshotEngine.capture('privacy_ceiling_notice', device: :both, metadata:, narrative:, callouts:) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/pages/#{host_page.slug}/edit"
      expect(page).to have_css(notice)
      page.execute_script("document.querySelector('#{notice}').scrollIntoView({block: 'start'})")
      sleep 0.5
    end
  end
end
