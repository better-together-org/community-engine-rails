# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for 0.11.0 federation, platform, and storage flows',
               :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:network_admin_email) { 'network-admin@example.test' }
  let(:manager_user) { BetterTogether::User.find_by!(email: 'manager@example.test') }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = configure_host_platform
    seed_release_state!
  end

  after do
    Current.platform = nil
  end

  it 'captures platform connections index release evidence' do
    capture_platform_connections_index
    expect(ENV.fetch('RUN_DOCS_SCREENSHOTS', nil)).to eq('1')
  end

  it 'captures platform connection editor release evidence' do
    capture_platform_connection_editor
    expect(ENV.fetch('RUN_DOCS_SCREENSHOTS', nil)).to eq('1')
  end

  it 'captures host platform profile release evidence' do
    capture_host_platform_profile
    expect(ENV.fetch('RUN_DOCS_SCREENSHOTS', nil)).to eq('1')
  end

  it 'captures person platform integrations release evidence' do
    capture_person_platform_integrations
    expect(ENV.fetch('RUN_DOCS_SCREENSHOTS', nil)).to eq('1')
  end

  it 'captures storage configurations index release evidence' do
    capture_storage_configurations_index
    expect(ENV.fetch('RUN_DOCS_SCREENSHOTS', nil)).to eq('1')
  end

  it 'captures storage configuration form release evidence' do
    capture_storage_configuration_form
    expect(ENV.fetch('RUN_DOCS_SCREENSHOTS', nil)).to eq('1')
  end

  private

  def capture_docs_screenshot(slug, feature_set:, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      slug,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        feature_set:,
        source_spec: self.class.metadata[:file_path]
      },
      &
    )
  end

  def host_platform
    @host_platform ||= BetterTogether::Platform.find_by!(host: true).tap do |platform|
      platform.update!(
        name: 'Community Engine Host',
        description: 'Primary host platform coordinating federation, storage, and member access.',
        identifier: 'community-engine-host',
        host_url: 'https://communityengine.example.test',
        time_zone: 'America/St_Johns'
      )
    end
  end

  # rubocop:disable Metrics/MethodLength
  def peer_platform
    @peer_platform ||= BetterTogether::Platform.find_or_initialize_by(identifier: 'neighbourhood-commons').tap do |platform|
      platform.assign_attributes(
        name: 'Neighbourhood Commons',
        description: 'External Community Engine peer used for mirrored content and federated account access.',
        host_url: 'https://commons.example.test',
        time_zone: 'America/Halifax',
        host: false,
        external: true,
        privacy: 'private',
        software_variant: 'community_engine',
        federation_protocol: 'ce_oauth',
        oauth_issuer_url: 'https://commons.example.test'
      )
      platform.community ||= create(:better_together_community)
      platform.save!
    end
  end
  # rubocop:enable Metrics/MethodLength

  def network_admin
    @network_admin ||= BetterTogether::User.find_by(email: network_admin_email) || create(
      :better_together_user,
      :confirmed,
      :network_admin,
      email: network_admin_email,
      password: 'SecureTest123!@#'
    )
  end

  # rubocop:disable Metrics/MethodLength
  def platform_connection
    @platform_connection ||= create(
      :better_together_platform_connection,
      :active,
      source_platform: host_platform,
      target_platform: peer_platform,
      connection_kind: 'peer',
      status: 'active',
      content_sharing_enabled: true,
      federation_auth_enabled: true,
      content_sharing_policy: 'mirror_network_feed',
      federation_auth_policy: 'api_read',
      share_posts: true,
      share_pages: true,
      share_events: true,
      allow_identity_scope: true,
      allow_profile_read_scope: true,
      allow_content_read_scope: true,
      allow_linked_content_read_scope: true,
      allow_content_write_scope: false,
      last_sync_status: 'succeeded',
      last_sync_started_at: 3.hours.ago.iso8601,
      last_synced_at: 2.hours.ago.iso8601,
      last_sync_item_count: 24,
      sync_cursor: 'cursor-2026-04-04T00:00:00Z'
    )
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def storage_configurations
    @storage_configurations ||= begin
      local = host_platform.storage_configurations.find_or_initialize_by(name: 'Host Local Disk')
      local.assign_attributes(service_type: 'local')
      local.save!

      amazon = host_platform.storage_configurations.find_or_initialize_by(name: 'Primary S3 Archive')
      amazon.assign_attributes(
        service_type: 'amazon',
        bucket: 'communityengine-production-assets',
        region: 'ca-central-1',
        access_key_id: 'AKIAIOSFODNN7EXAMPLE',
        secret_access_key: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'
      )
      amazon.save!

      compatible = host_platform.storage_configurations.find_or_initialize_by(name: 'Garage Object Store')
      compatible.assign_attributes(
        service_type: 's3_compatible',
        bucket: 'communityengine-edge-cache',
        region: 'us-east-1',
        endpoint: 'https://garage.internal.example.test',
        access_key_id: 'GKtest123456789',
        secret_access_key: 'supersecretkey0987654321abcdef'
      )
      compatible.save!

      host_platform.update!(active_storage_configuration: amazon)
      [local, amazon, compatible]
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  # rubocop:disable Metrics/MethodLength
  def seed_release_state!
    BetterTogether::AccessControlBuilder.seed_data
    network_admin
    platform_connection
    storage_configurations

    integration = BetterTogether::PersonPlatformIntegration.find_or_initialize_by(
      user: manager_user,
      platform: peer_platform,
      provider: 'github',
      uid: 'release-packet-github'
    )
    integration.assign_attributes(
      person: manager_user.person,
      access_token: 'token-release-packet',
      access_token_secret: 'secret-release-packet',
      handle: 'bt-platform-manager',
      name: 'BTS Platform Manager',
      profile_url: 'https://github.com/bt-platform-manager',
      expires_at: 1.hour.from_now,
      created_at: 2.days.ago
    )
    integration.save!
  end
  # rubocop:enable Metrics/MethodLength

  def login_as_network_admin
    @network_admin = nil unless BetterTogether::User.find_by(email: network_admin_email)
    network_admin
    capybara_sign_in_user(network_admin_email, 'SecureTest123!@#')
    expect(page).to have_no_current_path(new_user_session_path(locale: I18n.default_locale), wait: 10)
  end

  def login_as_platform_manager
    capybara_login_as_platform_manager
    expect(page).to have_no_current_path(new_user_session_path(locale: I18n.default_locale), wait: 10)
  end

  def scroll_heading_into_view(text)
    heading = find('h1', text:, wait: 10)
    page.execute_script('arguments[0].scrollIntoView({block: "start", behavior: "instant"})', heading.native)
    heading
  end

  # rubocop:disable Metrics/AbcSize
  def capture_platform_connections_index
    capture_docs_screenshot('release_0_11_0_platform_connections_index', feature_set: 'release_0_11_0_federation_platform') do
      login_as_network_admin
      visit better_together.platform_connections_path(locale: I18n.default_locale)

      expect(page).to have_text('Platform Connections')
      expect(page).to have_text('New Connection')
      expect(page).to have_text('Content Policy')
      scroll_heading_into_view('Platform Connections')
    end
  end

  def capture_platform_connection_editor
    capture_docs_screenshot('release_0_11_0_platform_connection_editor', feature_set: 'release_0_11_0_federation_platform') do
      login_as_network_admin
      visit better_together.edit_platform_connection_path(platform_connection, locale: I18n.default_locale)

      expect(page).to have_field('platform_connection[content_sharing_policy]')
      expect(page).to have_unchecked_field('platform_connection[allow_content_write_scope]')
      expect(page).to have_checked_field('platform_connection[share_posts]')
      page.execute_script('window.scrollTo(0, 0)')
    end
  end

  def capture_host_platform_profile
    capture_docs_screenshot('release_0_11_0_host_platform_profile', feature_set: 'release_0_11_0_federation_platform') do
      login_as_platform_manager
      visit better_together.platform_path(host_platform, locale: I18n.default_locale)

      expect(page).to have_text(host_platform.name)
      expect(page).to have_text('Identifier:')
      expect(page).to have_text('Time Zone:')
      expect(page).to have_text('Platform operations')
      expect(page).to have_link(
        'Manage storage',
        href: better_together.platform_storage_configurations_path(host_platform, locale: I18n.default_locale)
      )
      scroll_heading_into_view(host_platform.name)
    end
  end

  def capture_person_platform_integrations
    capture_docs_screenshot('release_0_11_0_person_platform_integrations', feature_set: 'release_0_11_0_federation_platform') do
      login_as_platform_manager
      visit better_together.person_platform_integrations_path(locale: I18n.default_locale)

      expect(page).to have_text('Github')
      expect(page).to have_text('bt-platform-manager')
      expect(page).to have_text('Connect a New Account')
      page.execute_script('window.scrollTo(0, 0)')
    end
  end

  def capture_storage_configurations_index
    capture_docs_screenshot('release_0_11_0_storage_configurations_index', feature_set: 'release_0_11_0_storage_adapter') do
      login_as_platform_manager
      visit better_together.platform_storage_configurations_path(host_platform, locale: I18n.default_locale)

      expect(page).to have_text('Storage Configurations')
      expect(page).to have_text('Currently Effective Storage')
      expect(page).to have_text('Primary S3 Archive')
      scroll_heading_into_view('Storage Configurations')
    end
  end

  def capture_storage_configuration_form
    capture_docs_screenshot('release_0_11_0_storage_configuration_form', feature_set: 'release_0_11_0_storage_adapter') do
      login_as_platform_manager
      visit better_together.new_platform_storage_configuration_path(host_platform, locale: I18n.default_locale)

      expect(page).to have_field('storage_configuration[name]')
      expect(page).to have_field('storage_configuration[service_type]')
      select 'S3-compatible (Garage / self-hosted)', from: 'storage_configuration[service_type]'
      expect(page).to have_text('S3 Credentials')
      expect(page).to have_field('storage_configuration[endpoint]')
      expect(page).to have_field('storage_configuration[bucket]')
      page.execute_script('window.scrollTo(0, 0)')
    end
  end
  # rubocop:enable Metrics/AbcSize
end
