# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/platform_domains_admin_spec.rb
#
# Documents the new PlatformDomainsController admin UI added for the 0.11.0
# multi-platform release-readiness work (community-engine-rails#1677) —
# closes the "no in-app UI to create a platform with a chosen domain" gap
# identified in the multi-platform/federation assessment (#1674).

require 'rails_helper'

RSpec.describe 'Documentation screenshots for Platform Domains admin UI', # rubocop:disable RSpec/SpecFilePathSuffix
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

  # A custom domain attached alongside the subdomain-style primary domain that
  # Platform#sync_primary_platform_domain! already auto-created for host_platform.
  let!(:custom_domain) do
    BetterTogether::PlatformDomain.create!(
      platform: host_platform,
      hostname: 'app.clientdomain.example',
      active: true,
      share_domain: false
    )
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after do
    Current.platform = nil
  end

  def screenshot_metadata(flow:, role:)
    {
      locale: I18n.default_locale,
      role:,
      feature_set: 'platform_domains',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end

  # ---------------------------------------------------------------------------
  # Index — populated (primary subdomain + one custom domain)
  # ---------------------------------------------------------------------------
  it 'captures the platform domains index — populated list' do
    custom_domain # ensure created before visiting

    BetterTogether::CapybaraScreenshotEngine.capture(
      'platform_domains_index_default',
      device: :both,
      metadata: screenshot_metadata(flow: 'platform_domains_index', role: 'platform_manager'),
      callouts: [
        {
          id: 'new_button',
          selector: '#new-platform-domain-btn',
          title: 'Add Domain',
          bullets: ['Opens the form to attach a new subdomain or custom domain to this platform.']
        },
        {
          id: 'primary_badge',
          selector: '.platform-domain-primary-badge',
          title: 'Primary badge',
          bullets: [
            'Marks the canonical domain used in links and redirects.',
            'Auto-created from the platform\'s host URL — cannot be deleted directly.'
          ]
        },
        {
          id: 'share_badge',
          selector: '.platform-domain-share-badge',
          title: 'Share badge',
          bullets: ['Marks which domain is used in generated share links.']
        },
        {
          id: 'status_column',
          selector: '#platform-domains-table thead th:nth-child(4)',
          title: 'Status column',
          bullets: ['Active domains resolve requests; inactive domains are kept but do not route traffic.']
        }
      ],
      narrative: {
        title: 'Platform Domains — Index',
        audience: %w[platform_manager platform_steward developer],
        journey_step: 'As a platform manager, I open Platform Domains to see every hostname ' \
                      'that resolves to my platform — the auto-created primary subdomain and any ' \
                      'custom domains I\'ve attached.',
        callouts: [
          { id: 'new_button', title: 'Add Domain',
            description: 'Opens the new-domain form with the subdomain-vs-custom-domain picker.' },
          { id: 'primary_badge', title: 'Primary badge',
            description: 'The canonical domain for this platform — set automatically from host_url ' \
                         'at provisioning time, cannot be removed without first making another domain primary.' },
          { id: 'share_badge', title: 'Share badge',
            description: 'Which domain generated share links use — independent of which domain is primary.' },
          { id: 'status_column', title: 'Status',
            description: 'Active/Inactive — inactive domains are retained (e.g. deprecated aliases) but ' \
                         'do not resolve traffic via PlatformContextMiddleware.' }
        ],
        accessibility_notes: 'Table has an aria-label; the Actions header is visually hidden but present ' \
                             'for screen readers; delete buttons use a turbo_confirm dialog before submitting.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.platform_platform_domains_path(host_platform, locale: I18n.default_locale)
      expect(page).to have_css('#platform-domains-table')
      expect(page).to have_content('app.clientdomain.example')
    end
  end

  # ---------------------------------------------------------------------------
  # New form — subdomain picker (default state)
  # ---------------------------------------------------------------------------
  it 'captures the new domain form — subdomain-of-host-domain state (default)' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'platform_domains_new_subdomain_state',
      device: :both,
      metadata: screenshot_metadata(flow: 'platform_domains_new', role: 'platform_manager'),
      callouts: [
        {
          id: 'kind_subdomain_radio',
          selector: '#platform_domain_kind_subdomain',
          title: 'Use a subdomain of the host domain',
          bullets: ['Selected by default — the common case for BTS-provisioned tenant platforms.']
        },
        {
          id: 'subdomain_fields',
          selector: '#platform-domain-subdomain-fields',
          title: 'Subdomain label + live preview',
          bullets: [
            'Enter just the label (e.g. "tenant-a") — the host domain suffix is appended automatically.',
            'Updates the real Hostname field below as you type.'
          ]
        },
        {
          id: 'hostname_field',
          selector: '#platform_domain_hostname',
          title: 'Hostname (submitted value)',
          bullets: ['The actual value that gets saved — both picker paths write to this one field.']
        },
        {
          id: 'submit_btn',
          selector: '#platform-domain-submit-btn',
          title: 'Create Domain',
          bullets: ['Saves the domain, validating uniqueness and primary/share-domain exclusivity.']
        }
      ],
      narrative: {
        title: 'Platform Domains — New (subdomain picker)',
        audience: %w[platform_manager platform_steward developer],
        journey_step: 'As a platform manager provisioning a new tenant, I choose "subdomain of the ' \
                      'host domain" and type just the label — the form fills in the full hostname for me.',
        callouts: [
          { id: 'kind_subdomain_radio', title: 'Subdomain picker (default)',
            description: 'The lower-friction path — no DNS/TLS work needed since it rides the ' \
                         'host domain\'s existing wildcard certificate and DNS record.' },
          { id: 'subdomain_fields', title: 'Live preview',
            description: 'A Stimulus controller (better-together--platform-domain-form) computes the ' \
                         'full hostname client-side and writes it into the real hostname field on input.' },
          { id: 'hostname_field', title: 'Real hostname field',
            description: 'Both the subdomain and custom-domain paths ultimately write the same field — ' \
                         'the distinction is presentation-only, not a data-model difference.' },
          { id: 'submit_btn', title: 'Create Domain', description: 'Submits the form.' }
        ],
        accessibility_notes: 'Radio buttons and their labels use matching for/id pairs; the live-updated ' \
                             'hostname field is a standard text input, not aria-live (no screen-reader ' \
                             'announcement on preview update — noted as a follow-up consideration).'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.new_platform_platform_domain_path(host_platform, locale: I18n.default_locale)
      expect(page).to have_css('#platform_domain_kind_subdomain')
    end
  end

  # ---------------------------------------------------------------------------
  # New form — custom domain picker (after toggling the radio)
  # ---------------------------------------------------------------------------
  it 'captures the new domain form — custom-domain state (after choosing "use my own domain")' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'platform_domains_new_custom_domain_state',
      device: :both,
      metadata: screenshot_metadata(flow: 'platform_domains_new', role: 'platform_manager'),
      callouts: [
        {
          id: 'kind_custom_radio',
          selector: '#platform_domain_kind_custom',
          title: 'Use my own domain',
          bullets: ['For client-owned domains pointed at this platform via a client-controlled DNS record.']
        },
        {
          id: 'custom_fields',
          selector: '#platform-domain-custom-fields',
          title: 'DNS/TLS guidance panel',
          bullets: [
            'Explains the client needs their own CNAME/A record and their own TLS certificate.',
            'The Hostname field below is now a plain free-text input (no auto-suffix).'
          ]
        },
        {
          id: 'hostname_field',
          selector: '#platform_domain_hostname',
          title: 'Hostname (free text for custom domains)',
          bullets: ['The steward types the full external hostname directly, e.g. app.clientdomain.example.']
        }
      ],
      narrative: {
        title: 'Platform Domains — New (custom domain picker)',
        audience: %w[platform_manager platform_steward developer],
        journey_step: 'As a platform manager onboarding a client with their own domain, I choose ' \
                      '"use my own domain" and see DNS/TLS guidance instead of a subdomain suffix.',
        callouts: [
          { id: 'kind_custom_radio', title: 'Custom domain picker',
            description: 'Toggling this radio hides the subdomain-suffix fields and shows the DNS/TLS ' \
                         'guidance panel instead — client-side only, via the same Stimulus controller.' },
          { id: 'custom_fields', title: 'DNS/TLS guidance',
            description: 'Static text echoing the operator guidance already documented in ' \
                         'docs/production/multi_platform_deployment.md — no new documentation content, ' \
                         'just surfaced in-context.' },
          { id: 'hostname_field', title: 'Free-text hostname',
            description: 'Same field as the subdomain path — no model or validation difference between ' \
                         'the two picker states.' }
        ],
        accessibility_notes: 'Toggling the radio moves focus-visible state correctly via native radio ' \
                             'input semantics; the guidance panel is a static alert region, not a live region.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.new_platform_platform_domain_path(host_platform, locale: I18n.default_locale)
      choose('platform_domain_kind_custom')
      expect(page).to have_css('#platform-domain-custom-fields', visible: true)
      expect(page).to have_no_css('#platform-domain-subdomain-fields', visible: true)
    end
  end

  # ---------------------------------------------------------------------------
  # Platform show page — "Domains" entry point in the Platform Operations card
  # ---------------------------------------------------------------------------
  it 'captures the platform show page — Domains link in Platform Operations' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'platform_domains_show_page_entry_point',
      device: :both,
      metadata: screenshot_metadata(flow: 'platform_show_operations', role: 'platform_manager'),
      callouts: [
        {
          id: 'domains_operations_link',
          selector: "a[href='#{better_together.platform_platform_domains_path(host_platform, locale: I18n.default_locale)}']",
          title: 'Domains',
          bullets: ['New entry point added alongside Manage storage / Feature access grants / Robots.']
        }
      ],
      narrative: {
        title: 'Platform Show — Platform Operations card',
        audience: %w[platform_manager platform_steward developer],
        journey_step: 'As a platform manager viewing my platform\'s About tab, I find "Domains" ' \
                      'alongside the other platform-operations links.',
        callouts: [
          { id: 'domains_operations_link', title: 'Domains entry point',
            description: 'Routes to the new platform_domains index for this platform; only shown when ' \
                         'PlatformDomainPolicy#index? passes for the signed-in manager on this platform.' }
        ],
        accessibility_notes: 'Rendered as a standard Bootstrap outline button alongside its siblings, ' \
                             'same focus/contrast treatment as the existing operations links.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.platform_path(host_platform, locale: I18n.default_locale)
      expect(page).to have_link(href: better_together.platform_platform_domains_path(host_platform, locale: I18n.default_locale))
    end
  end
end
