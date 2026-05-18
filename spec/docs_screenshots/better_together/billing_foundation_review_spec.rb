# frozen_string_literal: true

# rubocop:disable Layout/LineLength, Metrics/MethodLength, Metrics/AbcSize
require 'rails_helper'

RSpec.describe 'Documentation screenshots for billing foundation review',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:host_platform) { configure_host_platform }
  let!(:platform_manager) { BetterTogether::User.find_by!(email: 'manager@example.test') }
  let!(:community) { create(:better_together_community, name: 'Harbour Voices', slug: "harbour-voices-#{SecureRandom.hex(4)}") }
  let!(:sponsor_community) do
    create(:better_together_community, name: 'Collective Budget', slug: "collective-budget-#{SecureRandom.hex(4)}")
  end
  let!(:sponsored_by_person_community) do
    create(:better_together_community, name: 'Neighbourhood Pantry', slug: "neighbourhood-pantry-#{SecureRandom.hex(4)}")
  end
  let!(:current_plan) do
    create(
      :better_together_billing_plan,
      identifier: 'community-stewardship',
      name: 'Community Stewardship',
      amount_cents: 12_500,
      metadata: {
        'participant_summary' => 'Keeps the hosted community online, supported, and ready for members.',
        'participant_benefits' => ['Hosted community access', 'Priority steward support', 'Platform provisioning rights'],
        'beneficiary_label' => 'Community access',
        'hosted_access_level' => 'Partner',
        'support_tier' => 'Priority',
        'community_capacity_tier' => 'Growth'
      }
    )
  end
  let!(:personal_plan) do
    create(
      :better_together_billing_plan,
      identifier: 'personal-support',
      name: 'Personal Support',
      amount_cents: 5_000,
      metadata: {
        'eligible_billable_owner_types' => ['BetterTogether::Person'],
        'participant_summary' => 'Supports your participation and any communities you sponsor.',
        'participant_benefits' => ['Personal hosted access', 'Community sponsorship support'],
        'beneficiary_label' => 'Personal access'
      }
    )
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    seed_billing_review_state!
  end

  after do
    Current.platform = nil
  end

  it 'captures the community billing overview' do
    capture_docs_screenshot(
      'pr_1581_community_billing_overview',
      callouts: [
        { selector: '#hosted-entitlement-card', title: 'Hosted plan status',
          bullets: ['Shows whether the community currently qualifies for hosted services.', 'Explains what level of hosted service the plan unlocks.'] }
      ],
      narrative: {
        title: 'Community billing overview',
        audience: %w[board_member community_steward operator],
        journey_step: 'A steward reviews the community billing page to see who is paying, what the plan unlocks, whether payouts are configured, and whether Stripe events need attention.',
        callouts: [
          { title: 'Hosted plan status',
            description: 'This card translates billing into plain operational terms: whether the hosted community is active, what support tier it has, and whether platform provisioning is allowed.' },
          { title: 'Current subscription',
            description: 'This section makes sponsorship visible. If another person or community is paying, the page offers explicit takeover actions instead of assuming billing ownership.' },
          { title: 'Merchant account',
            description: 'Hosted billing and payout onboarding are intentionally separate. A community can have hosted access without yet being ready to receive payouts.' },
          { title: 'Billing activity alerts',
            description: 'This gives operators a plain dashboard for recent webhook trouble, including failures that may require replay or reconciliation.' },
          { title: 'Available hosted plans',
            description: 'The plan table explains what each recurring plan supports and which checkout path will charge the selected payer.' }
        ],
        accessibility_notes: 'All annotated targets use stable IDs or semantic classes. The page uses native headings, buttons, and table semantics so non-technical reviewers can cross-reference the screenshot with the live UI.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.community_billing_path(community, locale: I18n.default_locale)
      expect(page).to have_css('#community-billing-plans-table')
      expect(page).to have_text('Collective Budget')
    end
  end

  it 'captures the provision hosted platform form' do
    capture_docs_screenshot(
      'pr_1581_provision_hosted_platform',
      callouts: [
        { selector: '#community-platform-provision-form', title: 'Provision form',
          bullets: ['Collects the name, host URL, time zone, and visibility for the new hosted platform.', 'Only appears when the community has an active hosted entitlement.'] },
        { selector: '#hosted-entitlement-card', title: 'Eligibility checkpoint',
          bullets: ['Reminds reviewers why this community can provision a platform now.', 'Links platform creation back to the subscribed hosted plan.'] },
        { selector: "##{ActionView::RecordIdentifier.dom_id(community, :provision_platform_next_steps)}", title: 'What happens next', bullets: ['Explains the plain-language outcome of provisioning.', 'Helps non-technical reviewers understand the workflow without reading service code.'] }
      ],
      narrative: {
        title: 'Provision hosted platform',
        audience: %w[board_member community_steward operator],
        journey_step: 'A steward provisions a hosted platform only after the community has an active hosted plan.',
        callouts: [
          { title: 'Provision form',
            description: 'This is the operational handoff from billing into platform creation. It turns entitlement into a concrete hosted space with a URL and visibility policy.' },
          { title: 'Eligibility checkpoint',
            description: 'The entitlement card stays visible here so the reviewer can verify that platform creation is tied to an active hosted subscription.' },
          { title: 'What happens next',
            description: 'The checklist translates internal provisioning work into community-facing outcomes: a platform record, a linked community, a domain, and stewardship setup.' }
        ],
        accessibility_notes: 'The form uses labeled fields, a native select for visibility, and a stable form ID so screenshots and future accessibility checks remain deterministic.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.provision_platform_community_billing_path(community, locale: I18n.default_locale)
      expect(page).to have_css('#community-platform-provision-form')
      expect(page).to have_text('What happens next')
    end
  end

  it 'captures the personal billing overview' do
    capture_docs_screenshot(
      'pr_1581_person_billing_overview',
      callouts: [
        { selector: "##{ActionView::RecordIdentifier.dom_id(platform_manager.person, :current_subscription_card)}",
          title: 'Personal subscription', bullets: ['Shows the plan attached to the person as payer.', 'Surfaces portal issues and renewal timing.'] },
        { selector: "##{ActionView::RecordIdentifier.dom_id(platform_manager.person, :sponsored_communities_card)}", title: 'Sponsored communities', bullets: ['Lists communities this person is currently paying for.', 'Provides direct links to each community billing page.'] }
      ],
      narrative: {
        title: 'Personal billing overview',
        audience: %w[board_member sponsor operator],
        journey_step: 'A person reviews their own billing to see personal access, sponsorship commitments, and any payout onboarding status.',
        callouts: [
          { title: 'Personal subscription',
            description: 'This card is the person-facing equivalent of the community subscription card. It focuses on the individual payer and their current hosted support plan.' },
          { title: 'Sponsored communities',
            description: 'This is the key new accountability surface for sponsorship. A person can now see which communities their payment is supporting and jump directly to those community billing records.' },
          { title: 'Personal plans',
            description: 'Personal recurring plans are separated from community plans so the review packet makes clear who each plan is designed to support.' }
        ],
        accessibility_notes: 'The sponsored communities list and plan table both use stable identifiers and native list/table semantics for deterministic review coverage.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.person_billing_path(platform_manager.person, locale: I18n.default_locale)
      expect(page).to have_css('#person-billing-plans-table')
      expect(page).to have_text('Neighbourhood Pantry')
    end
  end

  it 'captures the billing plan index' do
    capture_docs_screenshot(
      'pr_1581_billing_plans_index',
      callouts: [
        { selector: '#new-billing-plan-btn', title: 'New plan',
          bullets: ['Creates a host-managed billing plan.', 'Only visible to plan stewards.'] },
        { selector: '#billing-plans-table', title: 'Plan catalog',
          bullets: ['Shows identifier, interval, price, activation state, and active subscriber count.', 'Gives operators a quick inventory of launch-ready hosted plans.'] }
      ],
      narrative: {
        title: 'Billing plans index',
        audience: %w[operator board_member],
        journey_step: 'A host steward reviews the plan catalog to see what recurring plans exist and how widely each one is in use.',
        callouts: [
          { title: 'New plan',
            description: 'Billing plans are centrally managed by the host. This button opens the editor for defining price-linked recurring plans.' },
          { title: 'Plan catalog',
            description: 'The table summarizes the operational state of each plan, including whether it is active and how many subscriptions currently depend on it.' }
        ],
        accessibility_notes: 'The primary call-to-action and the plan table each expose stable IDs for screenshot callouts and CI DOM contracts.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.billing_plans_path(locale: I18n.default_locale)
      expect(page).to have_css('#billing-plans-table')
      expect(page).to have_text('Community Stewardship')
    end
  end

  it 'captures the billing plan detail page' do
    capture_docs_screenshot(
      'pr_1581_billing_plan_detail',
      callouts: [
        { selector: "##{ActionView::RecordIdentifier.dom_id(current_plan, :summary_card)}", title: 'Plan summary',
          bullets: ['Shows the immutable Stripe-linked pricing identifiers.', 'Confirms whether the plan is active.'] },
        { selector: "##{ActionView::RecordIdentifier.dom_id(current_plan, :metadata_card)}", title: 'Plan metadata',
          bullets: ['Explains the plain-language copy shown to subscribers.', 'Defines hosted access level, support tier, and eligibility.'] },
        { selector: "##{ActionView::RecordIdentifier.dom_id(current_plan, :recent_subscribers_card)}", title: 'Recent subscribers', bullets: ['Shows who is currently using the plan.', 'Helps reviewers connect plan configuration to real stakeholders.'] }
      ],
      narrative: {
        title: 'Billing plan detail',
        audience: %w[operator board_member],
        journey_step: 'A host steward reviews a single plan to confirm subscriber-facing copy, pricing linkage, and current usage.',
        callouts: [
          { title: 'Plan summary',
            description: 'This section ties the human-friendly plan name back to the Stripe price identifier and the recurring interval that must remain stable after launch.' },
          { title: 'Plan metadata',
            description: 'These fields are what community members actually feel. They define the support promise, hosted access language, and who is allowed to be the payer.' },
          { title: 'Recent subscribers',
            description: 'Reviewers can see that subscriptions may belong to people or communities, which is central to the multi-owner billing foundation introduced in this PR.' }
        ],
        accessibility_notes: 'The detail page uses definition lists with stable field IDs so reviewers can reliably map screenshot annotations back to individual data points.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.billing_plan_path(current_plan, locale: I18n.default_locale)
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(current_plan, :metadata_card)}")
      expect(page).to have_text('Hosted community access')
    end
  end

  it 'captures the billing plan editor' do
    capture_docs_screenshot(
      'pr_1581_billing_plan_editor',
      callouts: [
        { selector: '#billing-plan-form', title: 'Plan editor',
          bullets: ['Central place to define recurring pricing, Stripe linkage, and subscriber-facing copy.', 'Keeps pricing and stewardship promises together in one form.'] },
        { selector: '#billing-plan-metadata-card', title: 'Subscriber-facing metadata',
          bullets: ['Controls the text and labels shown on community and personal billing pages.', 'Lets the host explain the plan in non-technical language.'] }
      ],
      narrative: {
        title: 'Billing plan editor',
        audience: %w[operator board_member],
        journey_step: 'A host steward edits a plan to define who can buy it and what hosted support the plan represents.',
        callouts: [
          { title: 'Plan editor',
            description: 'This form is the administrative source of truth for each hosted recurring plan. It combines pricing data, Stripe references, and the language that subscribers will read.' },
          { title: 'Subscriber-facing metadata',
            description: 'This section matters to non-technical reviewers because it directly shapes how the platform explains plan value and entitlement status to members and sponsors.' },
          { title: 'Eligible payers',
            description: 'The payer rules are what make personal sponsorship and community-to-community sponsorship possible without introducing ambiguous ownership.' }
        ],
        accessibility_notes: 'The editor exposes stable IDs for the full form and each major field cluster, allowing screenshot evidence and DOM contract tests to avoid fragile selectors.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.edit_billing_plan_path(current_plan, locale: I18n.default_locale)
      expect(page).to have_css('#billing-plan-form')
      expect(page).to have_text('Plan metadata')
    end
  end

  private

  def capture_docs_screenshot(slug, callouts:, narrative:, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      slug,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        feature_set: 'billing_foundation_review',
        source_spec: self.class.metadata[:file_path]
      },
      callouts:,
      narrative:,
      &
    )
  end

  def seed_billing_review_state!
    create('pay/customer', owner: sponsor_community, processor_id: 'cus_collective_budget')
    create('pay/customer', owner: platform_manager.person, processor_id: 'cus_manager_person')
    create('pay/customer', owner: community, processor_id: 'cus_harbour_voices')

    community_subscription = create(
      :better_together_billing_subscription,
      billing_plan: current_plan,
      billable_owner: sponsor_community,
      beneficiary: community,
      status: 'active',
      sync_source: 'stripe_webhook',
      last_synced_at: 2.hours.ago
    )

    create(
      :better_together_billing_subscription,
      billing_plan: personal_plan,
      billable_owner: platform_manager.person,
      beneficiary: platform_manager.person,
      status: 'active',
      sync_source: 'ce_push',
      last_synced_at: 1.hour.ago
    )

    create(
      :better_together_billing_subscription,
      billing_plan: current_plan,
      billable_owner: platform_manager.person,
      beneficiary: sponsored_by_person_community,
      status: 'active',
      sync_source: 'ce_push',
      last_synced_at: 3.hours.ago
    )

    create(
      'better_together/billing/merchant_account',
      owner: community,
      provider: 'stripe_connect',
      status: 'required_action',
      charges_enabled: false,
      payouts_enabled: false
    )

    create(
      'better_together/billing/merchant_account',
      :person_owned,
      :active,
      owner: platform_manager.person,
      provider: 'stripe_connect'
    )

    create(
      :better_together_billing_event,
      billable_owner: community,
      beneficiary: community,
      billing_subscription: community_subscription,
      event_type: 'invoice.payment_failed',
      event_id: 'evt_pr_1581_dead_letter',
      processing_status: 'dead_lettered',
      dead_lettered_at: 2.hours.ago,
      dead_letter_reason: 'repeated_failures',
      attempt_count: 4,
      last_attempted_at: 2.hours.ago,
      payload: {
        'id' => 'evt_pr_1581_dead_letter',
        'type' => 'invoice.payment_failed',
        'data' => { 'object' => { 'id' => 'in_pr_1581_dead_letter', 'object' => 'invoice' } }
      }
    )
  end
end
# rubocop:enable Layout/LineLength, Metrics/MethodLength, Metrics/AbcSize
