# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for feature access grants and developer settings',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:password) { 'SecureTest123!@#' }
  let!(:host_platform) { configure_host_platform }
  let!(:platform_manager) { find_or_create_test_user('manager@example.test', password, :platform_steward) }
  let!(:regular_user) { find_or_create_test_user('user@example.test', password, :user) }
  let!(:managed_platform) do
    create(:better_together_platform,
           identifier: "docs-feature-gate-platform-#{SecureRandom.hex(4)}",
           host_url: "https://docs-feature-gate-platform-#{SecureRandom.hex(4)}.example.test")
  end
  let!(:managed_role) { role_with_permissions('manage_platform_settings') }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    host_platform.update!(feature_gate_rollouts: { 'developer_settings' => 'stable' })

    create(:better_together_person_platform_membership,
           member: platform_manager.person,
           joinable: managed_platform,
           role: managed_role)
  end

  after do
    Current.platform = nil
  end

  it 'captures the feature access grants index' do
    create(:better_together_feature_access_grant,
           platform: managed_platform,
           feature_key: 'device_permissions',
           granted_by_person: platform_manager.person,
           notes: 'Docs review access')

    result = capture_docs_screenshot(
      'feature_access_grants_index',
      flow: 'grant_index',
      role: 'platform_manager',
      callouts: [
        {
          selector: 'table.table',
          title: 'Platform-scoped grant roster',
          bullets: [
            'The list is rendered for a manager with explicit access to the target platform.',
            'Each row shows the granted person, feature label, access level, status, and expiry.'
          ]
        }
      ]
    ) do
      capybara_login_as_platform_manager
      visit platform_feature_access_grants_path(managed_platform, locale:)

      expect(page).to have_text('Feature Access Grants')
      expect(page).to have_link('New grant')
      expect(page).to have_text(platform_manager.person.select_option_title)
      expect(page).to have_text('Device Permissions')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/feature_access_grants_index.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/feature_access_grants_index.png')
  end

  it 'captures the retired feature grant edit form fallback' do
    grant = create(:better_together_feature_access_grant,
                   platform: managed_platform,
                   feature_key: 'device_permissions',
                   granted_by_person: platform_manager.person)
    active_registry = BetterTogether::FeatureRegistry.all.except('device_permissions')

    allow(BetterTogether::FeatureRegistry).to receive(:find).and_call_original
    allow(BetterTogether::FeatureRegistry).to receive_messages(all: active_registry, keys: active_registry.keys)
    allow(BetterTogether::FeatureRegistry).to receive(:find).with('device_permissions').and_return(nil)

    result = capture_docs_screenshot(
      'feature_access_grant_retired_feature_edit',
      flow: 'grant_edit_retired_feature',
      role: 'platform_manager',
      callouts: [
        {
          selector: 'select[name="feature_access_grant[feature_key]"]',
          title: 'Retired feature fallback',
          bullets: [
            'Persisted grants retain the removed feature key as a selectable option.',
            'The form shows an explicit unknown or retired rollout state instead of raising.'
          ]
        }
      ]
    ) do
      capybara_login_as_platform_manager
      visit edit_platform_feature_access_grant_path(managed_platform, grant, locale:)

      expect(page).to have_text('Unknown feature (device_permissions)')
      expect(page).to have_text('Unknown / retired feature')
      expect(page).to have_select('feature_access_grant[feature_key]',
                                  selected: 'Unknown feature (device_permissions)')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/feature_access_grant_retired_feature_edit.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/feature_access_grant_retired_feature_edit.png')
  end

  it 'captures blocked personal oauth applications access when developer settings are off' do
    host_platform.update!(feature_gate_rollouts: { 'developer_settings' => 'off' })
    Current.platform = host_platform

    result = capture_docs_screenshot(
      'developer_settings_personal_oauth_blocked',
      flow: 'developer_settings_direct_route_block',
      role: 'user',
      callouts: [
        {
          selector: 'main',
          title: 'Direct route enforcement',
          bullets: [
            'The personal OAuth applications route now follows the developer_settings feature gate.',
            'Turning the gate off returns the same not-found surface even for a signed-in person.'
          ]
        }
      ]
    ) do
      capybara_login_as_user
      visit better_together.personal_oauth_applications_path(locale:)

      expect(page).to have_text('404 - Page Not Found')
      expect(page).to have_text('Go to Home')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/developer_settings_personal_oauth_blocked.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/developer_settings_personal_oauth_blocked.png')
  end

  private

  def capture_docs_screenshot(slug, flow:, role:, callouts: [], &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      slug,
      device: :both,
      metadata: screenshot_metadata(flow:, role:),
      callouts:,
      &
    )
  end

  def role_with_permissions(*permission_identifiers)
    role = create(:better_together_role, :platform_role)
    role.assign_resource_permissions(permission_identifiers)
    role
  end

  def screenshot_metadata(flow:, role:)
    {
      locale:,
      role:,
      feature_set: 'feature_access_grants_and_developer_settings',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end
end
