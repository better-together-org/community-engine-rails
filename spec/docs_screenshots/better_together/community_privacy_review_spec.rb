# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for community privacy', :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = configure_host_platform
    find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user)
  end

  after do
    Current.platform = nil
  end

  it 'captures checklist edit form screenshots with community privacy selected' do
    manager = BetterTogether::User.find_by!(email: 'manager@example.test')
    checklist = create(
      :better_together_checklist,
      creator: manager.person,
      privacy: 'community',
      title: 'Community Privacy Checklist'
    )

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'community_privacy_checklist_form',
      device: :both,
      metadata: screenshot_metadata(flow: 'checklist_privacy_authoring', role: 'platform_manager')
    ) do
      capybara_login_as_platform_manager
      visit better_together.edit_checklist_path(checklist, locale: I18n.default_locale)

      expect(page).to have_text('Edit Checklist')
      expect(page).to have_select('checklist[privacy]', selected: 'Community')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/community_privacy_checklist_form.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/community_privacy_checklist_form.png')
  end

  it 'captures community show screenshots with a rendered community badge' do
    community = create(
      :better_together_community,
      privacy: 'community',
      name: 'Community Privacy Circle',
      description: 'Shared planning space for community members.'
    )
    member_role = BetterTogether::Role.find_by!(identifier: 'community_member')
    user = BetterTogether::User.find_by!(email: 'user@example.test')
    BetterTogether::PersonCommunityMembership.find_or_create_by!(
      joinable: community,
      member: user.person,
      role: member_role
    )

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'community_privacy_badge',
      device: :both,
      metadata: screenshot_metadata(flow: 'community_privacy_visibility', role: 'community_member')
    ) do
      capybara_login_as_user
      visit better_together.community_path(community, locale: I18n.default_locale)

      expect(page).to have_text('Community Privacy Circle')
      expect(page).to have_css('.badge', text: 'Community')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/community_privacy_badge.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/community_privacy_badge.png')
  end

  private

  def screenshot_metadata(flow:, role:)
    {
      locale: I18n.default_locale,
      role:,
      feature_set: 'community_privacy_review',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end
end
