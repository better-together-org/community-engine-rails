# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/platform_trusted_domains_admin_spec.rb

require 'rails_helper'

RSpec.describe 'Documentation screenshots for Trusted Domains', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: true, allow_membership_requests: false)
    end
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after do
    Current.platform = nil
  end

  def screenshot_metadata(flow:, role:)
    { locale: I18n.default_locale, role:, feature_set: 'trusted_domains', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  it 'captures the trusted domains index' do
    create(:platform_trusted_domain, platform: host_platform, domain: 'nlmushrooms.ca', include_subdomains: true)
    create(:platform_trusted_domain, platform: host_platform, domain: 'club.example.org', enabled: false)

    BetterTogether::CapybaraScreenshotEngine.capture(
      'platform_trusted_domains_index',
      device: :both,
      metadata: screenshot_metadata(flow: 'trusted_domains_index', role: 'platform_manager'),
      callouts: [
        { id: 'explanation', selector: '#trusted-domains-explanation', avoid_container_selector: '.container',
          title: 'What a trusted domain does',
          bullets: ['Verified or confirmed addresses on a listed domain join without waiting for review.'] },
        { id: 'new_button', selector: '#new-platform-trusted-domain-btn', avoid_container_selector: '.container',
          title: 'Add trusted domain',
          bullets: ['Opens the form for a domain, a community role and the confirmations.'] }
      ],
      narrative: {
        title: 'Trusted domains - index',
        audience: %w[platform_manager platform_steward],
        journey_step: 'As a steward, I list the email domains whose verified addresses join this platform automatically.',
        callouts: [
          { id: 'explanation', title: 'What a trusted domain does',
            description: 'States that only verified or confirmed addresses qualify and every grant is logged.' },
          { id: 'new_button', title: 'Add trusted domain', description: 'Starts a new trusted domain entry.' }
        ],
        accessibility_notes: 'The table has an aria-label and a visually hidden actions header.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.platform_platform_trusted_domains_path(host_platform, locale: I18n.default_locale)
      expect(page).to have_css('#platform-trusted-domains-table')
    end
  end

  it 'captures the new trusted domain form' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'platform_trusted_domains_new',
      device: :both,
      metadata: screenshot_metadata(flow: 'trusted_domains_new', role: 'platform_manager'),
      callouts: [
        { id: 'role', selector: '#platform_trusted_domain_role_id', avoid_container_selector: '.container',
          title: 'Community role',
          bullets: ['Only community roles are offered; platform and steward roles cannot be granted by domain.'] },
        { id: 'ceiling', selector: '#platform_trusted_domain_role_ceiling_confirmed', avoid_container_selector: '.container',
          title: 'Role confirmation',
          bullets: ['The steward confirms that everyone with a verified address receives this role.'] }
      ],
      narrative: {
        title: 'Trusted domains - new',
        audience: %w[platform_manager platform_steward],
        journey_step: 'As a steward, I add a domain and choose the role its verified addresses receive.',
        callouts: [
          { id: 'role', title: 'Community role', description: 'Limited to community roles.' },
          { id: 'ceiling', title: 'Role confirmation', description: 'An explicit acknowledgement of the automatic grant.' }
        ],
        accessibility_notes: 'Every field has a label and the hints are linked with aria-describedby.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.new_platform_platform_trusted_domain_path(host_platform, locale: I18n.default_locale)
      expect(page).to have_css('#platform-trusted-domain-form')
    end
  end

  it 'captures the sign-up page for a trusted domain' do
    create(:platform_trusted_domain, platform: host_platform, domain: 'nlmushrooms.ca')

    BetterTogether::CapybaraScreenshotEngine.capture(
      'trusted_domain_sign_up',
      device: :both,
      metadata: screenshot_metadata(flow: 'trusted_domain_sign_up', role: 'guest'),
      narrative: {
        title: 'Trusted domains - sign-up',
        audience: %w[guest],
        journey_step: 'As a visitor with a trusted address, I register and confirm my email to join.',
        callouts: [],
        accessibility_notes: 'The notice is plain text in an alert region above the form.'
      }
    ) do
      visit better_together.new_user_registration_path(locale: I18n.default_locale, trusted_domain: 1)
      expect(page).to have_css('#trusted-domain-confirmation-notice')
    end
  end
end
