# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/platform_domains_steward_request_spec.rb
#
# Documents the domain guardrails (HPS-4): a managed platform's steward requests a domain and it waits,
# inactive, for the operator to activate it.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for steward domain requests', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  # The browser reaches the app at 127.0.0.1; the managed platform answers on 'localhost', the same server.
  # The managed platform has its own domain name. Chrome maps *.test to the app server (spec/support/capybara.rb)
  # and one app server and one port serve every hostname.
  # One app instance on one port serves every hostname, as in production. Run this spec on a single worker.
  let(:server_port) { 43_999 }
  let(:managed_host) { "club-#{SecureRandom.hex(3)}.managed.test" }
  let(:managed_origin) { "http://#{managed_host}:#{server_port}" }
  # Domain resolution goes by hostname, so the platform's own URL carries no port.
  let(:setup) { managed_platform_setup(managed_attributes: { host_url: "http://#{managed_host}" }) }
  let(:managed_platform) { setup.managed_platform }
  let(:steward) { setup.managed_steward }
  let(:zone) { setup.operator_platform.primary_platform_domain.hostname }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Capybara.server_port = server_port
    # Relative visits (the sign-in helper) must go to the managed hostname, not Capybara's own 127.0.0.1.
    Capybara.app_host = managed_origin
    Capybara.asset_host = managed_origin
    Current.platform = setup.operator_platform
    setup.operator_platform.update!(privacy: 'public', requires_invitation: false)
  end

  after do
    Capybara.app_host = nil
    Capybara.asset_host = nil
    Current.platform = nil
  end

  # A managed steward works on their own platform's domain.
  def managed_url(path)
    "#{managed_origin}#{path}"
  end

  def sign_in_on_managed_platform
    visit managed_url(better_together.new_user_session_path(locale: I18n.default_locale))
    capybara_sign_in_user(steward.email, 'SecureTest123!@#')
  end

  def screenshot_metadata(flow:)
    {
      locale: I18n.default_locale,
      role: 'managed_platform_steward',
      feature_set: 'platform_domains',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end

  it 'captures the new domain form as a managed platform steward' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'platform_domains_new_steward_request',
      device: :both,
      metadata: screenshot_metadata(flow: 'platform_domains_new_steward'),
      callouts: [
        {
          id: 'activation_note',
          selector: '#platform-domain-activation-note',
          title: 'Operator activates',
          bullets: ['There is no Active checkbox for stewards. The operator turns the domain on after checking it.']
        },
        {
          id: 'submit_btn',
          selector: '#platform-domain-submit-btn',
          title: 'Request domain',
          bullets: ['Saves the domain as inactive.']
        }
      ],
      narrative: {
        title: 'Platform Domains - New (managed steward)',
        audience: %w[platform_steward operator_steward],
        journey_step: 'As the steward of a managed platform, I ask for a subdomain. I cannot switch it on ' \
                      'myself, so the form tells me my operator will activate it.',
        callouts: [
          { id: 'activation_note', title: 'Operator activates',
            description: 'Stewards only request. The Active checkbox is shown to the governing operator.' },
          { id: 'submit_btn', title: 'Request domain', description: 'Creates the domain inactive and not primary.' }
        ],
        accessibility_notes: 'The activation note is plain text in the form flow with a stable id.'
      }
    ) do
      sign_in_on_managed_platform
      visit managed_url(better_together.new_platform_platform_domain_path(managed_platform, locale: I18n.default_locale))
      expect(page).to have_css('#platform-domain-activation-note')
      scroll_to(find('#platform-domain-activation-note'), align: :center)
    end
  end

  it 'captures the domains index with a pending requested domain' do
    create(:better_together_platform_domain, platform: managed_platform, hostname: "club.#{zone}", active: false)

    BetterTogether::CapybaraScreenshotEngine.capture(
      'platform_domains_index_pending_request',
      device: :both,
      metadata: screenshot_metadata(flow: 'platform_domains_index_pending'),
      callouts: [
        {
          id: 'pending_domain',
          selector: '#platform-domains-table tbody tr:last-child .platform-domain-active-badge',
          title: 'Pending',
          bullets: ['Shown as Inactive until the operator activates it. It does not resolve traffic yet.']
        }
      ],
      narrative: {
        title: 'Platform Domains - Index with a pending request',
        audience: %w[platform_steward operator_steward],
        journey_step: 'After I request a domain it appears in the list as Inactive while my operator reviews it.',
        callouts: [
          { id: 'pending_domain', title: 'Pending',
            description: 'Inactive domains are kept but do not route traffic.' }
        ],
        accessibility_notes: 'Status is text, not colour alone.'
      }
    ) do
      sign_in_on_managed_platform
      visit managed_url(better_together.platform_platform_domains_path(managed_platform, locale: I18n.default_locale))
      expect(page).to have_css('#platform-domains-table')
      expect(page).to have_content("club.#{zone}")
    end
  end
end
