# frozen_string_literal: true

# rubocop:disable Layout/LineLength
require 'rails_helper'

# Coverage gap found while reviewing the billing-sponsorship PR stack (#1709-#1721):
# HostedEntitlementResolver gained a fourth status (:grace, between :attention and
# :inactive) in this PR, but billing_foundation_review_spec.rb's community fixture
# only ever exercises :active — no screenshot documents the grace-period badge or
# explainer text a steward actually sees when a subscription has lapsed but is still
# within the app-owned grace window.
RSpec.describe 'Documentation screenshots for hosted entitlement grace period',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:host_platform) { configure_host_platform }
  let!(:platform_manager) { BetterTogether::User.find_by!(email: 'manager@example.test') }
  let!(:community) { create(:better_together_community, name: 'Harbour Voices', slug: "harbour-voices-#{SecureRandom.hex(4)}") }
  let!(:current_plan) do
    create(
      :better_together_billing_plan,
      identifier: 'community-stewardship',
      name: 'Community Stewardship',
      amount_cents: 12_500
    )
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    create('pay/customer', owner: community, processor_id: 'cus_harbour_voices_grace')
    create(
      :better_together_billing_subscription,
      billing_plan: current_plan,
      billable_owner: community,
      status: 'canceled',
      sync_source: 'stripe_webhook',
      metadata: { 'lapsed_at' => 2.days.ago.iso8601 }
    )
  end

  after { Current.platform = nil }

  it 'captures the hosted entitlement card in grace period' do
    capture_docs_screenshot(
      'hosted_entitlement_grace_period',
      callouts: [
        { selector: '#hosted-entitlement-card .hosted-entitlement-status-badge', title: 'Grace period badge',
          bullets: ['Distinct from both "active" (green) and "billing attention needed" (yellow) — this is the app-owned second buffer after Stripe\'s own dunning retries are exhausted.'] }
      ],
      narrative: {
        title: 'Hosted entitlement — grace period',
        audience: %w[board_member community_steward operator],
        journey_step: 'A steward opens community billing after a payment has genuinely lapsed (not just a Stripe retry) and sees exactly how much runway remains before hosted access actually pauses.',
        callouts: [
          { title: 'Grace period badge',
            description: 'HostedEntitlementResolver#hosted_status_for returns :grace once Subscription#in_grace_period? is true — the subscription is no longer activeish (status left trialing/active/past_due) but grace_period_expires_at (lapsed_at + BT_BILLING_HOSTED_ACCESS_GRACE_PERIOD_DAYS, 7 by default) is still in the future. Access itself stays on during this window (Subscription#access_active? OR-combines activeish? and in_grace_period?) — only the badge and explainer text change to warn the steward before anything actually breaks.' }
        ],
        accessibility_notes: 'The badge uses text-bg-danger (red) styling with the same badge markup pattern as the other three statuses, so screen readers announce the status text itself rather than relying on color alone.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.community_billing_path(community, locale: I18n.default_locale)
      expect(page).to have_css('.hosted-entitlement-status-badge', text: 'grace period')
    end
  end

  private

  def capture_docs_screenshot(slug, callouts:, narrative:, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      slug,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        feature_set: 'hosted_entitlement_grace_period',
        source_spec: self.class.metadata[:file_path]
      },
      callouts:,
      narrative:,
      &
    )
  end
end
# rubocop:enable Layout/LineLength
