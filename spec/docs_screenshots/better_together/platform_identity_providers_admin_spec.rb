# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/platform_identity_providers_admin_spec.rb
#
# Documents the host-dashboard screens for a platform's OAuth sign-in providers.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for Platform sign-in providers admin UI', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: false)
    end
  end
  let!(:github_platform) do
    BetterTogether::Platform.find_by(identifier: 'github', external: true) ||
      create(:better_together_platform, identifier: 'github', external: true, name: 'GitHub',
                                        url: 'https://github.com')
  end
  let!(:provider) do
    create(:better_together_platform_identity_provider, platform: host_platform, provider_platform: github_platform,
                                                        strategy: 'github', client_id: 'Iv1.example-client-id')
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after do
    Current.platform = nil
  end

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'platform_identity_providers', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  it 'captures the sign-in providers index' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'platform_identity_providers_index',
      device: :both,
      metadata: screenshot_metadata(flow: 'platform_identity_providers_index'),
      callouts: [
        { id: 'new_button', selector: '#new-platform-identity-provider-btn', title: 'Add provider',
          bullets: ['Opens the form to configure a sign-in provider for this platform.'] },
        { id: 'env_note', selector: '#platform-identity-providers-env-note', title: 'Environment fallback',
          bullets: ['Providers without a row use the server environment variables.'] }
      ],
      narrative: {
        title: 'Sign-in providers: index',
        audience: %w[platform_manager platform_steward developer],
        journey_step: 'As a platform manager, I open Sign-in providers from the platform page to see which ' \
                      'OAuth providers this platform offers.',
        callouts: [
          { id: 'new_button', title: 'Add provider', description: 'Opens the new provider form.' },
          { id: 'env_note', title: 'Environment fallback',
            description: 'A provider with no row here still works if its environment variables are set.' }
        ],
        accessibility_notes: 'The table has an aria-label and a visually hidden Actions header; delete uses a confirm dialog.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.platform_platform_identity_providers_path(host_platform, locale: I18n.default_locale)
      expect(page).to have_css('#platform-identity-providers-table')
      expect(page).to have_content('Iv1.example-client-id')
    end
  end

  it 'captures the new provider form' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'platform_identity_providers_new',
      device: :both,
      metadata: screenshot_metadata(flow: 'platform_identity_providers_new'),
      callouts: [
        { id: 'strategy', selector: '#platform_identity_provider_strategy', title: 'Provider',
          bullets: ['Choose from the providers the engine supports.'] },
        { id: 'client_secret', selector: '#platform_identity_provider_client_secret', title: 'Client secret',
          bullets: ['Write-only. Leave blank on edit to keep the current secret.'] },
        { id: 'submit', selector: '#platform-identity-provider-submit-btn', title: 'Add provider',
          bullets: ['Saves the configuration for this platform.'] }
      ],
      narrative: {
        title: 'Sign-in providers: new',
        audience: %w[platform_manager platform_steward developer],
        journey_step: 'As a platform manager, I enter the OAuth client id and secret from the provider console.',
        callouts: [
          { id: 'strategy', title: 'Provider', description: 'The provider catalog entry this row configures.' },
          { id: 'client_secret', title: 'Client secret', description: 'Stored encrypted, never shown again.' },
          { id: 'submit', title: 'Add provider', description: 'Submits the form.' }
        ],
        accessibility_notes: 'Every field has a label with a matching for/id; the secret field uses autocomplete new-password.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.new_platform_platform_identity_provider_path(host_platform, locale: I18n.default_locale)
      expect(page).to have_css('#platform_identity_provider_strategy')
    end
  end
end
