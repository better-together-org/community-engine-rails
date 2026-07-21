# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/new_platform_setup_wizard_spec.rb
#
# Documents the new_platform_setup wizard (community-engine-rails#1682) —
# provisions additional tenant platforms end-to-end, distinct from the
# singleton host_setup wizard. Each `it` block independently drives the
# wizard from a fresh login up to the step being captured, since
# CapybaraScreenshotEngine.capture resets Capybara sessions (and therefore
# auth cookies) before every capture.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the new_platform_setup wizard', # rubocop:disable RSpec/SpecFilePathSuffix
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
      feature_set: 'new_platform_setup',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end

  def advance_past_welcome
    find('#new-platform-setup-welcome-submit-btn').click
    expect(page).to have_css('#new_platform_platform_name', wait: 10, visible: :all)
  end

  def fill_in_platform_identity_and_submit(suffix:)
    fill_in 'new_platform_platform_name', with: "Tenant Platform #{suffix}"
    fill_in 'new_platform_platform_description', with: 'A place where neighbors and friends support each other.'
    fill_in 'new_platform_platform_host_url', with: "https://tenant-#{suffix}.example.com"
    find('#new-platform-setup-platform-identity-submit-btn').click
    expect(page).to have_css('#new_platform_domain_hostname', wait: 10, visible: :all)
  end

  def skip_domain_step
    find('#new-platform-setup-domain-skip-btn').click
    expect(page).to have_css('#new_platform_steward_email', wait: 10, visible: :all)
  end

  def fill_in_steward_account_and_submit(suffix:)
    fill_in 'new_platform_steward_email', with: "steward-#{suffix}@example.com"
    fill_in 'new_platform_steward_password', with: '!StrongPass12345?'
    fill_in 'new_platform_steward_password_confirmation', with: '!StrongPass12345?'
    fill_in 'new_platform_steward_person_name', with: 'New Platform Steward'
    fill_in 'new_platform_steward_person_identifier', with: "steward-#{suffix}"
    fill_in 'new_platform_steward_person_description', with: 'First steward of this new platform.'
    find('#new-platform-setup-steward-account-submit-btn').click
    expect(page).to have_current_path(%r{/invite_members\z}, wait: 10)
  end

  def send_one_invitation(suffix:)
    fill_in 'new_platform_invitation_invitee_email', with: "invitee-#{suffix}@example.test"
    find('#new-platform-setup-invite-members-submit-btn').click
    expect(page).to have_content("invitee-#{suffix}@example.test", wait: 10)
  end

  def skip_invite_members_step
    find('#new-platform-setup-invite-members-skip-btn').click
    expect(page).to have_current_path(%r{/review_and_launch\z}, wait: 10)
  end

  # ---------------------------------------------------------------------------
  # Entry point — platforms#index "Provision New Platform" button
  # ---------------------------------------------------------------------------
  it 'captures the platforms index — Provision New Platform entry point' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'new_platform_setup_entry_point',
      device: :both,
      metadata: screenshot_metadata(flow: 'entry_point', role: 'platform_manager'),
      callouts: [
        {
          id: 'provision_button',
          selector: "a[href='#{better_together.new_platform_setup_path(locale: I18n.default_locale)}']",
          title: 'Provision New Platform',
          bullets: [
            'New entry point that starts the new_platform_setup wizard.',
            'Only rendered when PlatformPolicy#create? passes for the signed-in user.'
          ]
        }
      ],
      narrative: {
        title: 'Platforms Index — Provision New Platform entry point',
        audience: %w[platform_manager developer],
        journey_step: 'As a platform manager, I open Platforms and see a "Provision New Platform" ' \
                      'button that starts the guided wizard, instead of the bare external-registration form.',
        callouts: [
          { id: 'provision_button', title: 'Provision New Platform',
            description: 'Routes to new_platform_setup_path, which creates a draft Platform + Wizard ' \
                         'and redirects into step 1 (welcome). Gated on policy(Platform.new).create? — ' \
                         'an instance, not the bare class, since PlatformPolicy#create? touches record.class.' }
        ],
        accessibility_notes: 'Rendered as a standard Bootstrap btn-primary link in the page header.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.platforms_path(locale: I18n.default_locale)
      expect(page).to have_link(href: better_together.new_platform_setup_path(locale: I18n.default_locale))
    end
  end

  # ---------------------------------------------------------------------------
  # Step 1 — welcome
  # ---------------------------------------------------------------------------
  it 'captures the welcome step' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'new_platform_setup_welcome',
      device: :both,
      metadata: screenshot_metadata(flow: 'new_platform_setup_welcome', role: 'platform_manager'),
      callouts: [
        {
          id: 'progress_nav',
          selector: '#new-platform-setup-progress',
          title: 'Step progress',
          bullets: ['Named step list with aria-current="step", plus a percentage progress bar.']
        },
        {
          id: 'locale_select',
          selector: '#new_platform_setup_locale',
          title: 'Locale',
          bullets: ['Sets the locale used for the rest of the wizard and the new platform itself.']
        },
        {
          id: 'next_button',
          selector: '#new-platform-setup-welcome-submit-btn',
          title: 'Next',
          bullets: ['Advances to platform_identity — no data is created by this step.']
        }
      ],
      narrative: {
        title: 'New Platform Setup — Welcome',
        audience: %w[platform_manager platform_steward developer],
        journey_step: 'As a platform manager kicking off provisioning, I choose a locale and read what ' \
                      'the wizard is about to walk me through.',
        callouts: [
          { id: 'progress_nav', title: 'Step progress',
            description: 'Six named steps; the active one is bold and carries aria-current="step".' },
          { id: 'locale_select', title: 'Locale', description: 'Applies to the wizard UI and the new platform.' },
          { id: 'next_button', title: 'Next', description: 'Advances to platform_identity.' }
        ],
        accessibility_notes: 'Locale select has an aria-describedby help text; progress bar has an aria-label.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.new_platform_setup_path(locale: I18n.default_locale)
      expect(page).to have_css('#new_platform_setup_locale', wait: 10)
    end
  end

  # ---------------------------------------------------------------------------
  # Step 2 — platform_identity
  # ---------------------------------------------------------------------------
  it 'captures the platform_identity step' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'new_platform_setup_platform_identity',
      device: :both,
      metadata: screenshot_metadata(flow: 'new_platform_setup_platform_identity', role: 'platform_manager'),
      callouts: [
        {
          id: 'name_field',
          selector: '#new_platform_platform_name',
          title: 'Name',
          bullets: ['Replaces the draft platform\'s placeholder name.']
        },
        {
          id: 'host_url_field',
          selector: '#new_platform_platform_host_url',
          title: 'Host URL',
          bullets: ['Replaces the draft platform\'s placeholder pending.invalid host URL.']
        },
        {
          id: 'privacy_field',
          selector: '#new_platform_platform_privacy',
          title: 'Privacy',
          bullets: ['Public or private — controls default visibility for the new platform.']
        },
        {
          id: 'time_zone_field',
          selector: '#new_platform_platform_time_zone',
          title: 'Time zone',
          bullets: ['Pre-selects Etc/UTC — the IANA identifier the select actually renders as an option.']
        }
      ],
      narrative: {
        title: 'New Platform Setup — Platform Identity',
        audience: %w[platform_manager platform_steward developer],
        journey_step: 'As a platform manager, I replace the draft platform\'s placeholder name/host_url ' \
                      'with the real values and set its description, privacy, and time zone.',
        callouts: [
          { id: 'name_field', title: 'Name', description: 'Required; validated for presence.' },
          { id: 'host_url_field', title: 'Host URL',
            description: 'Required, format- and uniqueness-validated at the model level via NewPlatformIdentityForm.' },
          { id: 'privacy_field', title: 'Privacy', description: 'Maps to Platform#privacy enum.' },
          { id: 'time_zone_field', title: 'Time zone',
            description: 'Uses the shared iana_time_zone_select helper (slim_select_controller.js).' }
        ],
        accessibility_notes: 'Every field has an aria-describedby pointing at its help text; invalid fields ' \
                             'get is-invalid plus the shared wizard error summary (role="alert").'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.new_platform_setup_path(locale: I18n.default_locale)
      advance_past_welcome
      expect(page).to have_css('#new_platform_platform_name', wait: 10)
    end
  end

  # ---------------------------------------------------------------------------
  # Step 3 — domain (optional)
  # ---------------------------------------------------------------------------
  it 'captures the domain step' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'new_platform_setup_domain',
      device: :both,
      metadata: screenshot_metadata(flow: 'new_platform_setup_domain', role: 'platform_manager'),
      callouts: [
        {
          id: 'submit_btn',
          selector: '#new-platform-setup-domain-submit-btn',
          title: 'Add and continue',
          bullets: ['Creates a PlatformDomain for the new platform and advances.']
        },
        {
          id: 'skip_btn',
          selector: '#new-platform-setup-domain-skip-btn',
          title: 'Skip',
          bullets: ['Advances without creating a domain — the platform keeps its placeholder host_url only.']
        },
        {
          id: 'hostname_field',
          selector: '#new_platform_domain_hostname',
          title: 'Hostname',
          bullets: ['Subdomain-of-host-domain or a fully custom domain — same underlying field either way.']
        }
      ],
      narrative: {
        title: 'New Platform Setup — Domain (optional)',
        audience: %w[platform_manager platform_steward developer],
        journey_step: 'As a platform manager, I optionally attach a subdomain or a client-owned custom ' \
                      'domain to the new platform, reusing the same picker introduced in PR #1677.',
        callouts: [
          { id: 'hostname_field', title: 'Hostname', description: 'Same field backs both picker paths.' },
          { id: 'submit_btn', title: 'Add and continue', description: 'Persists a PlatformDomain.' },
          { id: 'skip_btn', title: 'Skip',
            description: 'A blank required field or this button both advance the wizard without creating anything.' }
        ],
        accessibility_notes: 'Radio buttons and labels use matching for/id pairs; toggling reveals/hides ' \
                             'fields client-side via better-together--platform-domain-form.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.new_platform_setup_path(locale: I18n.default_locale)
      advance_past_welcome
      fill_in_platform_identity_and_submit(suffix: SecureRandom.hex(4))
      expect(page).to have_css('#new_platform_domain_hostname', wait: 10)
    end
  end

  # ---------------------------------------------------------------------------
  # Step 4 — steward_account
  # ---------------------------------------------------------------------------
  it 'captures the steward_account step' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'new_platform_setup_steward_account',
      device: :both,
      metadata: screenshot_metadata(flow: 'new_platform_setup_steward_account', role: 'platform_manager'),
      callouts: [
        {
          id: 'email_field',
          selector: '#new_platform_steward_email',
          title: 'Steward email',
          bullets: ['Creates the first User for the new platform.']
        },
        {
          id: 'password_field',
          selector: '#new_platform_steward_password',
          title: 'Password',
          bullets: ['Show/hide toggle via better_together--password-toggle Stimulus controller.']
        },
        {
          id: 'person_name_field',
          selector: '#new_platform_steward_person_name',
          title: 'Person name',
          bullets: ['Creates the paired Person profile for the steward.']
        }
      ],
      narrative: {
        title: 'New Platform Setup — Steward Account',
        audience: %w[platform_manager platform_steward developer],
        journey_step: 'As a platform manager, I create the first steward\'s login and profile, who will ' \
                      'be granted platform_steward and community_governance_council roles on the new platform.',
        callouts: [
          { id: 'email_field', title: 'Steward email', description: 'Devise User#email; validated for uniqueness.' },
          { id: 'password_field', title: 'Password',
            description: 'Devise password + confirmation, with a visibility toggle.' },
          { id: 'person_name_field', title: 'Person name', description: 'Start of the fields_for :person block.' }
        ],
        accessibility_notes: 'Password toggle button has aria-label + tooltip; all fields have aria-describedby.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.new_platform_setup_path(locale: I18n.default_locale)
      advance_past_welcome
      fill_in_platform_identity_and_submit(suffix: SecureRandom.hex(4))
      skip_domain_step
      expect(page).to have_css('#new_platform_steward_email', wait: 10)
    end
  end

  # ---------------------------------------------------------------------------
  # Step 5 — invite_members (optional), with one invitation already sent
  # ---------------------------------------------------------------------------
  it 'captures the invite_members step with one invitation already sent' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'new_platform_setup_invite_members',
      device: :both,
      metadata: screenshot_metadata(flow: 'new_platform_setup_invite_members', role: 'platform_manager'),
      callouts: [
        {
          id: 'skip_btn',
          selector: '#new-platform-setup-invite-members-skip-btn',
          title: 'Continue',
          bullets: ['Advances to review_and_launch — sending zero, one, or many invitations is all valid.']
        },
        {
          id: 'invitee_email_field',
          selector: '#new_platform_invitation_invitee_email',
          title: 'Invitee email',
          bullets: ['Sends a PlatformInvitation via the existing admin invitation flow.']
        }
      ],
      narrative: {
        title: 'New Platform Setup — Invite Members (optional)',
        audience: %w[platform_manager platform_steward developer],
        journey_step: 'As a platform manager, I optionally send initial member invitations one at a time, ' \
                      'seeing the running list of sent invitations below the form.',
        callouts: [
          { id: 'invitee_email_field', title: 'Invitee email', description: 'Reuses the PlatformInvitation model.' },
          { id: 'skip_btn', title: 'Continue', description: 'Same "advance without creating" pattern as domain.' }
        ],
        accessibility_notes: 'The sent-invitations list has an aria-label matching the section heading.'
      }
    ) do
      suffix = SecureRandom.hex(4)

      capybara_login_as_platform_manager
      visit better_together.new_platform_setup_path(locale: I18n.default_locale)
      advance_past_welcome
      fill_in_platform_identity_and_submit(suffix:)
      skip_domain_step
      fill_in_steward_account_and_submit(suffix:)
      send_one_invitation(suffix:)
      expect(page).to have_content("invitee-#{suffix}@example.test")
    end
  end

  # ---------------------------------------------------------------------------
  # Step 6 — review_and_launch
  # ---------------------------------------------------------------------------
  it 'captures the review_and_launch step' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'new_platform_setup_review_and_launch',
      device: :both,
      metadata: screenshot_metadata(flow: 'new_platform_setup_review_and_launch', role: 'platform_manager'),
      callouts: [
        {
          id: 'edit_platform_identity',
          selector: '#review-platform-identity-heading',
          title: 'Platform Identity recap',
          bullets: ['Each section has its own distinct "Edit <section>" link — never a bare "Edit".']
        },
        {
          id: 'edit_steward_account',
          selector: '#review-steward-account-heading',
          title: 'Steward Account recap',
          bullets: ['Shows the steward\'s name and email.']
        },
        {
          id: 'launch_btn',
          selector: '#new-platform-setup-launch-btn',
          title: 'Launch',
          bullets: ['Final confirmation — marks the wizard/platform as launched.']
        }
      ],
      narrative: {
        title: 'New Platform Setup — Review and Launch',
        audience: %w[platform_manager platform_steward developer],
        journey_step: 'As a platform manager, I review everything I entered across all five prior steps, ' \
                      'each with its own edit link back to that step, then confirm launch.',
        callouts: [
          { id: 'edit_platform_identity', title: 'Platform Identity recap',
            description: 'Name, description, host_url, privacy, time_zone.' },
          { id: 'edit_steward_account', title: 'Steward Account recap', description: 'Name + email summary.' },
          { id: 'launch_btn', title: 'Launch', description: 'POSTs to the launch_platform step action.' }
        ],
        accessibility_notes: 'Each recap section is aria-labelledby its own heading id; edit links have ' \
                             'distinct accessible names (verified in new_platform_setup_wizard_accessibility_spec.rb).'
      }
    ) do
      suffix = SecureRandom.hex(4)

      capybara_login_as_platform_manager
      visit better_together.new_platform_setup_path(locale: I18n.default_locale)
      advance_past_welcome
      fill_in_platform_identity_and_submit(suffix:)
      skip_domain_step
      fill_in_steward_account_and_submit(suffix:)
      skip_invite_members_step
      expect(page).to have_css('#new-platform-setup-launch-btn', wait: 10)
    end
  end
end
