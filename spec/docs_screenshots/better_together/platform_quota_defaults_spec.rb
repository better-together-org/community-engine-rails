# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for platform quota defaults',
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
    host_platform.update!(quota_default_limits: { 'media_storage' => { 'person' => 536_870_912 } })
  end

  after do
    host_platform.update!(quota_default_limits: {})
    Current.platform = nil
  end

  it 'captures the quota defaults card on the platform edit form' do
    result = capture_docs_screenshot(
      'platform_quota_defaults',
      flow: 'platform_edit',
      role: 'platform_manager',
      callouts: [
        {
          selector: "##{ActionView::RecordIdentifier.dom_id(host_platform, :quota_defaults_media_storage)}",
          title: 'Starting quotas',
          bullets: ['Pick a storage size, or use the default.']
        }
      ]
    ) do
      capybara_login_as_platform_manager
      visit edit_platform_path(host_platform, locale:)

      card = find("##{ActionView::RecordIdentifier.dom_id(host_platform, :quota_defaults)}")
      card.scroll_to(:center)
      select_name = 'platform[quota_default_limits][media_storage][person]'
      expect(page).to have_css("select[name='#{select_name}']", visible: :all, wait: 10)
      expect(page).to have_css('.ss-main', wait: 5)
      expect(page).to have_css('.ss-main .ss-single', text: '512 MiB', wait: 5)
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/platform_quota_defaults.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/platform_quota_defaults.png')
  end

  private

  def capture_docs_screenshot(name, flow:, role:, callouts: [], &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role:,
        feature_set: 'platform_quota_defaults',
        flow:,
        source_spec: self.class.metadata[:file_path]
      },
      callouts:,
      &
    )
  end
end
