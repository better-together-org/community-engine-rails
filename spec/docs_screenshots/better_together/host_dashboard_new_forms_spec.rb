# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for 0.11.0 host dashboard forms',
               :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::DocsScreenshotHelpers

  let(:locale) { I18n.default_locale }
  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) { configure_host_platform }
  let(:network_admin_email) { 'forms-network-admin@example.test' }
  let(:network_admin) do
    BetterTogether::User.find_by(email: network_admin_email) ||
      create(:better_together_user, :confirmed, :network_admin, email: network_admin_email, password: 'SecureTest123!@#')
  end
  let(:peer_platform) do
    BetterTogether::Platform.find_by(identifier: 'docs-forms-peer') ||
      create(:better_together_platform, name: 'Valley Commons', identifier: 'docs-forms-peer',
                                        external: true, privacy: 'public')
  end
  let(:connection) do
    create(:better_together_platform_connection, :active, source_platform: host_platform, target_platform: peer_platform)
  end
  let(:custom_domain) do
    BetterTogether::PlatformDomain.find_by(hostname: 'app.clientdomain.example') ||
      BetterTogether::PlatformDomain.create!(platform: host_platform, hostname: 'app.clientdomain.example',
                                             active: true, share_domain: false)
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    manager
    network_admin
    connection
    custom_domain
  end

  after do
    Current.platform = nil
  end

  it 'captures the new feature access grant form' do
    docs_screenshot('feature_access_grants_new', role: 'platform_manager', feature_set: 'feature_access_grants') do
      capybara_login_as_platform_manager
      visit better_together.new_platform_feature_access_grant_path(host_platform, locale:)

      expect(page).to have_css('form')
      expect(page).to have_css('select, input[type=text]', minimum: 1)
    end
  end

  it 'captures the edit platform domain form' do
    docs_screenshot('platform_domains_edit', role: 'platform_manager', feature_set: 'platform_domains') do
      capybara_login_as_platform_manager
      visit better_together.edit_platform_platform_domain_path(host_platform, custom_domain, locale:)

      expect(page).to have_css('h1', text: 'app.clientdomain.example')
      expect(page).to have_field('platform_domain[hostname]')
    end
  end

  it 'captures the new platform connection form' do
    docs_screenshot('platform_connections_new', role: 'platform_manager', feature_set: 'platform_connections') do
      capybara_sign_in_user(network_admin_email, 'SecureTest123!@#')
      visit better_together.new_platform_connection_path(locale:)

      expect(page).to have_css('form')
      expect(page).to have_css('select', minimum: 1)
    end
  end

  it 'captures a platform connection' do
    docs_screenshot('platform_connections_show', role: 'platform_manager', feature_set: 'platform_connections') do
      capybara_sign_in_user(network_admin_email, 'SecureTest123!@#')
      visit better_together.platform_connection_path(connection, locale:)

      expect(page).to have_text('Valley Commons')
    end
  end
end
