# frozen_string_literal: true

# rubocop:disable Layout/LineLength, Metrics/MethodLength
require 'rails_helper'

# Coverage gap found while reviewing the billing-entitlements PR stack
# (#1709-#1721): the sponsorship redesign introduced BetterTogether::Billing::Sponsorship,
# the SponsorshipsController token-based review page, and the
# _sponsorship_panels.html.erb partial, but none of it had dedicated
# screenshot coverage — billing_foundation_review_spec.rb only captures the
# panel's empty state buried below the fold on the community/person billing
# pages. This spec documents the actual sponsorship lifecycle states.
RSpec.describe 'Documentation screenshots for sponsorship panel states',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:host_platform) { configure_host_platform }
  let!(:platform_manager) { BetterTogether::User.find_by!(email: 'manager@example.test') }
  let!(:sponsor_community) do
    create(:better_together_community, name: 'Collective Budget', slug: "collective-budget-#{SecureRandom.hex(4)}")
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  it 'captures a sponsorship offer awaiting the viewer decision' do
    sponsorship = create(
      :better_together_billing_sponsorship,
      sponsor: sponsor_community,
      beneficiary: platform_manager.person,
      status: 'pending'
    )

    capture_docs_screenshot(
      'sponsorship_review_awaiting_decision',
      callouts: [
        { selector: '#sponsorship-from-to-summary', title: 'Offer summary',
          bullets: ['Names the sponsor and the beneficiary in plain language.'] },
        { selector: '#sponsorship-decision-actions', title: 'Accept or decline',
          bullets: ['Only shown to the beneficiary while the offer is pending.', 'Accepting activates the sponsorship immediately; declining ends it permanently.'] }
      ],
      narrative: {
        title: 'Sponsorship offer — awaiting the beneficiary\'s decision',
        audience: %w[board_member sponsor operator],
        journey_step: 'A person or community steward opens a sponsorship offer link (from an email or the billing page) and decides whether to accept funding from another party.',
        callouts: [
          { title: 'Offer summary',
            description: 'Uses sponsorship_counterpart_name to show a person or community name regardless of which polymorphic type is on either side of the offer.' },
          { title: 'Accept or decline',
            description: 'Pundit\'s SponsorshipPolicy#accept?/#decline? gate this — only the beneficiary (or someone who stewards it) sees these buttons; the sponsor sees the read-only "awaiting a decision" state instead (see sponsorship_review_awaiting_beneficiary for that view).' }
        ],
        accessibility_notes: 'Both actions are button_to submit buttons (not JS-only links), so they work with keyboard navigation and without JavaScript.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.sponsorship_path(sponsorship.token, locale: I18n.default_locale)
      expect(page).to have_css('#sponsorship-decision-actions')
    end
  end

  it 'captures a sponsorship offer from the sponsor\'s read-only view' do
    other_person = create(:better_together_person, name: 'Other Beneficiary')
    sponsorship = create(
      :better_together_billing_sponsorship,
      sponsor: platform_manager.person,
      beneficiary: other_person,
      status: 'pending'
    )

    capture_docs_screenshot(
      'sponsorship_review_awaiting_beneficiary',
      callouts: [
        { selector: '#sponsorship-awaiting-beneficiary-alert', title: 'Awaiting beneficiary',
          bullets: ['The sponsor cannot accept or decline their own offer.', 'Confirms the offer was sent and names who needs to act on it.'] }
      ],
      narrative: {
        title: 'Sponsorship offer — sponsor\'s read-only view',
        audience: %w[sponsor operator],
        journey_step: 'A sponsor who just sent an offer revisits the review link to confirm it is still pending.',
        callouts: [
          { title: 'Awaiting beneficiary',
            description: 'Same #show action and same underlying Sponsorship record as the beneficiary\'s view — only the policy check on accept? determines which branch of the view renders.' }
        ],
        accessibility_notes: 'Informational alert uses the standard Bootstrap alert-info role; no interactive elements in this state.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.sponsorship_path(sponsorship.token, locale: I18n.default_locale)
      expect(page).to have_css('#sponsorship-awaiting-beneficiary-alert')
    end
  end

  it 'captures an active sponsorship' do
    sponsorship = create(
      :better_together_billing_sponsorship,
      sponsor: sponsor_community,
      beneficiary: platform_manager.person,
      status: 'active',
      accepted_at: 1.day.ago
    )

    capture_docs_screenshot(
      'sponsorship_review_active',
      callouts: [
        { selector: '#sponsorship-active-alert', title: 'Active sponsorship',
          bullets: ['Confirms the sponsorship is live and contributions are being credited.'] },
        { selector: '#sponsorship-end-btn', title: 'Stop this sponsorship',
          bullets: ['Either party can end an active sponsorship at any time.', 'Ending does not retroactively remove contributions already credited.', 'Session follow-up: now requires a confirmation prompt before firing — the native browser dialog itself isn\'t visible in a static screenshot, but this is the only destructive action on this page and it previously fired immediately on a single click.'] }
      ],
      narrative: {
        title: 'Sponsorship — active',
        audience: %w[board_member sponsor operator],
        journey_step: 'Either party revisits the sponsorship link to confirm it is active or to end it.',
        callouts: [
          { title: 'Active sponsorship',
            description: 'Reachable from both "accepted" and "active" statuses (Sponsorship#status_accepted? transitions to active on first contribution) — the view intentionally treats both as one visual state.' },
          { title: 'Stop this sponsorship',
            description: 'SponsorshipPolicy#end? authorizes either the sponsor or the beneficiary, unlike accept?/decline? which are beneficiary-only. Session follow-up: this button now carries data-turbo-confirm, matching the confirm pattern already used by the plan-deactivate toggle elsewhere in billing — previously a misclick immediately ended what may be an active funding relationship with no warning.' }
        ],
        accessibility_notes: 'The end button is a standard button_to submit with data-turbo-confirm; browsers render the confirmation as a native modal dialog, so it is keyboard-operable and announced by screen readers without any additional app-level work. The status alert uses alert-success semantics.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.sponsorship_path(sponsorship.token, locale: I18n.default_locale)
      expect(page).to have_css('#sponsorship-end-btn')
    end
  end

  private

  def capture_docs_screenshot(slug, callouts:, narrative:, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      slug,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        feature_set: 'sponsorship_panel_states',
        source_spec: self.class.metadata[:file_path]
      },
      callouts:,
      narrative:,
      &
    )
  end
end
# rubocop:enable Layout/LineLength, Metrics/MethodLength
