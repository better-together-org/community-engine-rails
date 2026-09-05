# frozen_string_literal: true

# DOCS SCREENSHOT SPEC TEMPLATE
#
# Copy this file to spec/docs_screenshots/better_together/<feature>_spec.rb and
# replace placeholder values. Remove this comment block before committing.
#
# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/<feature>_spec.rb
#
# Assets land in:
#   docs/screenshots/desktop/<slug>.png           (1440x1600)
#   docs/screenshots/desktop/<slug>.json          (metadata sidecar)
#   docs/screenshots/desktop/<slug>.narrative.yml (narrative sidecar, if narrative: provided)
#   docs/screenshots/mobile/<slug>.png            (430x1400)
#   (same .json and .narrative.yml for mobile)
#
# See skills/ce-pr-docs/SKILL.md for the full PR documentation workflow.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for <Feature Name>', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  # Adjust let! blocks to match your feature's prerequisites.
  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: false)
    end
  end

  # ---------------------------------------------------------------------------
  # Callout definitions
  #
  # Each entry describes one element to highlight. The selector is resolved
  # in the browser after the block runs. id: is used to cross-reference entries
  # in the narrative sidecar. Remove entries that don't apply.
  # ---------------------------------------------------------------------------
  let(:callouts) do
    [
      {
        id: 'primary_action',
        selector: '.btn-primary',
        title: 'Primary action button',
        bullets: [
          'Describe what this button does.',
          'Mention any state changes or confirmations.'
        ]
      },
      {
        id: 'status_indicator',
        selector: '.badge',
        title: 'Status badge',
        bullets: [
          'Green = active, yellow = inactive, grey = expired.'
        ]
      }
    ]
  end

  # ---------------------------------------------------------------------------
  # Narrative sidecar
  #
  # Written as <slug>.narrative.yml alongside the JSON metadata sidecar.
  # audience: roles who will read this screenshot in PR docs.
  # journey_step: one sentence from that user's perspective.
  # callouts: array of {id:, title:, description:} matching callout id: fields above.
  # accessibility_notes: summary of a11y coverage for this surface.
  # ---------------------------------------------------------------------------
  let(:narrative) do
    {
      title: '<Feature> -- <View Name>',
      audience: %w[admin developer content_editor],
      journey_step: 'As an admin, I <verb> the <feature> to <goal>.',
      callouts: [
        {
          id: 'primary_action',
          title: 'Primary action button',
          description: 'Clicking this <does what>. Describe the user-visible outcome.'
        },
        {
          id: 'status_indicator',
          title: 'Status badge',
          description: 'Green = active, yellow = inactive, grey = expired.'
        }
      ],
      accessibility_notes: 'All action buttons have aria-label; decorative icons are aria-hidden.'
    }
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after do
    Current.platform = nil
  end

  # ---------------------------------------------------------------------------
  # Screenshot scenarios
  # ---------------------------------------------------------------------------

  it 'captures the default state' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'feature_view_default', # slug: replace with e.g. 'short_links_index_default'
      device: :both,
      metadata: screenshot_metadata(flow: 'feature_view', role: 'platform_manager'),
      callouts:,
      narrative:
    ) do
      capybara_login_as_platform_manager

      # Replace with the actual route helper, e.g.:
      # visit better_together.short_links_path(locale: I18n.default_locale)
      raise NotImplementedError, 'Replace the visit placeholder with the actual route helper'
    end
  end

  # Add additional `it` blocks for other states (empty state, error state, etc.)
  # Keep each scenario focused on one specific UI state.
end
