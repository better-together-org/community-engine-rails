# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for access mode panels',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }
  let!(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let!(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: false)
      platform.primary_community&.update!(allow_membership_requests: false)
    end
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after do
    Current.platform = nil
  end

  it 'captures a public platform in invitation-only mode' do
    platform = create(
      :better_together_platform,
      :public,
      name: 'Invitation Only Platform',
      requires_invitation: true,
      allow_membership_requests: false
    )

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'platform_access_mode_invitation_only',
      device: :both,
      metadata: screenshot_metadata(flow: 'platform_invitation_only', role: 'platform_manager')
    ) do
      capybara_login_as_platform_manager
      visit better_together.platform_path(platform, locale: I18n.default_locale)

      expect(page).to have_text('Invitation Only Platform')
      expect(page).to have_text('How people join')
      expect(page).to have_text('Invitation only')
      expect(page).to have_text('People need an invitation before they can create an account here.')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/platform_access_mode_invitation_only.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/platform_access_mode_invitation_only.png')
  end

  it 'captures a community in open join mode for a signed-in person' do
    community = create(
      :better_together_community,
      name: 'Open Join Community',
      privacy: 'public',
      allow_membership_requests: false
    )

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'community_access_mode_open_join',
      device: :both,
      metadata: screenshot_metadata(flow: 'community_open_join', role: 'user')
    ) do
      capybara_login_as_user
      visit better_together.community_path(community, locale: I18n.default_locale)

      expect(page).to have_text('How people join')
      expect(page).to have_text('Open join')
      expect(page).to have_button('Join now')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/community_access_mode_open_join.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/community_access_mode_open_join.png')
  end

  it 'captures a community in request-to-join mode for a signed-in person' do
    community = create(
      :better_together_community,
      name: 'Request Join Community',
      privacy: 'public',
      allow_membership_requests: true
    )

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'community_access_mode_request_to_join',
      device: :both,
      metadata: screenshot_metadata(flow: 'community_request_join', role: 'user')
    ) do
      capybara_login_as_user
      visit better_together.community_path(community, locale: I18n.default_locale)

      expect(page).to have_text('How people join')
      expect(page).to have_text('Request to join')
      expect(page).to have_button('Request to join')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/community_access_mode_request_to_join.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/community_access_mode_request_to_join.png')
  end

  private

  def screenshot_metadata(flow:, role:)
    {
      locale: I18n.default_locale,
      role:,
      feature_set: 'access_mode_panel_review',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end
end
