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
  let!(:solidarity_plan) do
    create(
      :better_together_billing_plan,
      identifier: 'harbour-solidarity',
      name: 'Harbour Solidarity',
      amount_cents: 2_500,
      metadata: {
        'participant_summary' => 'A reduced-contribution option for smaller co-ops and community groups.',
        'participant_benefits' => ['Hosted community access', 'Steward support'],
        'beneficiary_label' => 'Community access',
        'pricing_tier' => 'solidarity_small',
        'solidarity_description' => 'For co-ops and community groups with fewer than 20 active members.'
      }
    )
  end
  let!(:sponsorship_contribution_plan) do
    create(
      :better_together_billing_plan,
      :one_time,
      identifier: 'sponsor-a-community',
      name: 'Sponsor a Community',
      amount_cents: 2_000,
      metadata: { 'sponsorship_contribution' => true }
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
          bullets: ['Shows whether the community currently qualifies for hosted services.', 'Explains what level of hosted service the plan unlocks.'] },
        { selector: "##{ActionView::RecordIdentifier.dom_id(community, :sponsorship_received_notice)}",
          title: 'Sponsorship received',
          bullets: ['Shown whenever a sponsor\'s contribution has been credited to this community\'s balance.'] }
      ],
      narrative: {
        title: 'Community billing overview',
        audience: %w[board_member community_steward operator],
        journey_step: 'A steward reviews the community billing page to see whether the community\'s own plan is active, whether it is being sponsored by others, what it can contribute to other communities, whether payouts are configured, and whether Stripe events need attention.',
        callouts: [
          { title: 'Hosted plan status',
            description: 'This card translates billing into plain operational terms: whether the hosted community is active, what support tier it has, and whether platform provisioning is allowed.' },
          { title: 'Current subscription',
            description: 'This community\'s own hosted plan, if it pays for itself — a subscription is always self-funded (billable_owner and beneficiary are the same record now; see Subscription#beneficiary). Replaces the old "takeover" mechanism (billing ownership reassignment) entirely — a third party funding this community\'s access instead does so via the Sponsorship panel below, crediting this community\'s own Stripe balance rather than taking over the subscription record.' },
          { title: 'Sponsorship received',
            description: 'A Billing::Sponsorship crediting this community\'s balance via a MonetaryContribution, replacing the removed takeover UI ("Let Collective Budget pay instead"). This banner only shows the total credited so far — see the Sponsorship panel below for who the sponsor is and accept/decline actions.' },
          { title: 'Contribute to another community',
            description: 'This community can fund another community\'s hosted-access balance directly, without ever taking over that community\'s subscription ownership.' },
          { title: 'Sponsorship',
            description: 'A sponsor\'s contribution is credited to the beneficiary\'s own Stripe Customer Balance; it never reassigns billable_owner on a Subscription record. This panel (below the fixed screenshot viewport on this page, so it has no callout box here — see sponsorship_panel_states for the dedicated, annotated view) shows who currently sponsors this account, who this account sponsors, and lets a steward offer to sponsor another community or person.' },
          { title: 'Merchant account',
            description: 'Hosted billing and payout onboarding are intentionally separate. A community can have hosted access without yet being ready to receive payouts.' },
          { title: 'Billing activity alerts',
            description: 'This gives operators a plain dashboard for recent webhook trouble, including failures that may require replay or reconciliation.' },
          { title: 'Available hosted plans',
            description: 'The plan table explains what each recurring plan supports and which checkout path will charge the selected payer.' },
          { title: 'Solidarity pricing tier',
            description: 'Session follow-up: plans with a non-standard pricing_tier now show a badge and the plan\'s own solidarity_description directly on this table, surfacing a value that previously only existed in the admin plan editor. It sorts to the top row of "Available hosted plans" (lowest amount_cents first) but falls below the fixed screenshot viewport on this page, so it has no callout box here — see pr_1581_billing_plan_solidarity_detail for the dedicated, annotated view of these fields.' }
        ],
        accessibility_notes: 'All annotated targets use stable IDs or semantic classes. The page uses native headings, buttons, and table semantics so non-technical reviewers can cross-reference the screenshot with the live UI. Session follow-up: the billing activity alert banners now carry role="alert" so assistive technology announces dead-letter/repeated-failure/unresolved-drift states.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.community_billing_path(community, locale: I18n.default_locale)
      expect(page).to have_css('#community-billing-plans-table')
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(community, :sponsorship_received_notice)}",
                               text: '$50.00')
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(community, :sponsor_contribution_card)}")
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(community, :sponsorship_panels)}",
                               text: 'Collective Budget')
      expect(page).to have_css('.billing-plan-solidarity-badge', text: 'Solidarity — Small')
    end
  end

  it 'captures the checkout-session pending state on browser return from Stripe' do
    checkout_session_id = 'cs_pr1581_pending_demo'
    dom_id = BetterTogether::Billing::CheckoutSessionSyncBroadcaster.target_dom_id(checkout_session_id)

    capture_docs_screenshot(
      'pr_1581_checkout_session_pending',
      callouts: [
        { selector: "##{dom_id}", title: 'Confirming payment',
          bullets: ['The page renders immediately instead of blocking on a live Stripe API call.', 'A background job confirms the payment and updates this region in place once it completes.'] }
      ],
      narrative: {
        title: 'Checkout return — confirming payment (async)',
        audience: %w[board_member community_steward operator developer],
        journey_step: 'A steward is redirected back from Stripe Checkout. The billing page used to make a live, synchronous Stripe API call on the request thread right at this moment, with no timeout handling — this pending state is what replaces that wait.',
        callouts: [
          { title: 'Confirming payment',
            description: 'Session follow-up (second-round remediation): CommunityBillingsController#show used to call StripeCheckoutSessionSync (and, inside it, Stripe::Checkout::Session.retrieve) synchronously on the request thread. It is now purely a valid_checkout_session_id? pre-check that enqueues BetterTogether::Billing::SyncCheckoutSessionJob and renders this pending region immediately; see pr_1581_checkout_session_resolved for the state the job pushes here via Turbo Streams once it completes. The webhook-driven sync (StripeEventProcessor) remains the authoritative source of truth throughout and is unaffected by this change.' }
        ],
        accessibility_notes: 'The pending region uses role="status" and aria-live="polite" so assistive technology announces it without requiring focus, and announces the replacement content again when the Turbo Stream update lands.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.community_billing_path(community, locale: I18n.default_locale, checkout_session_id:)
      expect(page).to have_css("##{dom_id}", text: 'Confirming your payment with Stripe')
    end
  end

  it 'captures the checkout-session resolved state pushed via Turbo Streams' do
    checkout_session_id = 'cs_pr1581_resolved_demo'
    dom_id = BetterTogether::Billing::CheckoutSessionSyncBroadcaster.target_dom_id(checkout_session_id)

    capture_docs_screenshot(
      'pr_1581_checkout_session_resolved',
      callouts: [
        { selector: "##{dom_id}", title: 'Payment confirmed',
          bullets: ['Delivered by CheckoutSessionSyncBroadcaster once SyncCheckoutSessionJob finishes.', 'Replaces the pending spinner in place — no page reload.'] }
      ],
      narrative: {
        title: 'Checkout return — payment confirmed (async)',
        audience: %w[board_member community_steward operator developer],
        journey_step: 'Once SyncCheckoutSessionJob finishes syncing with Stripe, CheckoutSessionSyncBroadcaster replaces the pending region shown in pr_1581_checkout_session_pending with this confirmation, over the Turbo Stream subscription the page opened on load.',
        callouts: [
          { title: 'Payment confirmed',
            description: 'Reuses the exact same message text the old synchronous flash.now-based code showed ("Stripe checkout was synchronized successfully."), just delivered via a Turbo Stream replace instead of being present in the initial response body. This screenshot renders the actual _checkout_session_result partial directly (rather than racing a live ActionCable delivery under headless Chrome, which this codebase\'s own Turbo-Stream-broadcast feature specs — see spec/features/conversations/send_message_spec.rb — already flag as flaky) so the captured markup is byte-for-byte what the broadcaster sends in production.' }
        ],
        accessibility_notes: 'Same role="status"/aria-live="polite" region as the pending state, so the confirmation is announced without the user needing to have focus on the page.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.community_billing_path(community, locale: I18n.default_locale, checkout_session_id:)
      expect(page).to have_css("##{dom_id}")

      result_html = BetterTogether::ApplicationController.render(
        partial: 'better_together/shared/checkout_session_result',
        locals: { dom_id:, messages: [{ variant: :notice, text: 'Stripe checkout was synchronized successfully.' }] }
      )
      page.execute_script("document.getElementById(#{dom_id.to_json}).outerHTML = #{result_html.to_json};")
      expect(page).to have_content('Stripe checkout was synchronized successfully.')
    end
  end

  # NOTE: (session follow-up, unresolved) a dedicated screenshot for the new
  # SlimSelect-backed "contribute to another community" search field
  # (community_billings/show.html.erb's sponsor_contribution_card, replacing
  # the old raw-slug text field) was attempted here and removed. The field
  # itself works (covered by community_billings_spec.rb's search_beneficiaries
  # request specs and the community_billing_overview capture below, which
  # renders the same page successfully); annotating it specifically hit a
  # ScreenshotCalloutProcessor/Selenium failure ("page.current_path is empty")
  # that reproduced identically with and without an explicit scroll-into-view,
  # both in isolation and as part of the full suite. sponsor_contribution_card
  # sits below the fixed 1440x1600 screenshot viewport on this page (same
  # constraint already documented on pr_1581_community_billing_overview and
  # pr_1581_person_billing_overview for the plans table and sponsorship
  # panel) — resolving a callout box on an off-screen SlimSelect widget likely
  # needs either a shorter seed fixture (fewer cards above it) or a
  # scroll-aware fix in ScreenshotCalloutProcessor itself. Follow-up needed
  # before this field gets its own annotated screenshot.

  it 'captures the provision hosted platform entry point redirecting into the setup wizard' do
    capture_docs_screenshot(
      'pr_1581_provision_hosted_platform',
      callouts: [
        { selector: '#new-platform-setup-progress', title: 'Setup wizard',
          bullets: ['This is where the billing entry point now lands, instead of a separate provisioning form.', 'Same six-step wizard used by the staff-facing "Provision New Platform" entry point on the platforms index.'] },
        { selector: '#new_platform_setup_locale', title: 'Locale', bullets: ['Sets the locale for the rest of the wizard and the new platform itself.'] },
        { selector: '#new-platform-setup-welcome-submit-btn', title: 'Next', bullets: ['Advances to platform_identity, where the real name/host URL/visibility are collected.'] }
      ],
      narrative: {
        title: 'Provision hosted platform — now via the setup wizard',
        audience: %w[board_member community_steward operator],
        journey_step: 'A steward provisions a hosted platform only after the community has an active hosted plan; clicking "Provision hosted platform" checks that entitlement server-side, then hands off straight into the shared platform setup wizard.',
        callouts: [
          { title: 'Setup wizard',
            description: 'Session follow-up ("Phase 5: Billing entry-point wiring", previously scoped but never built): the standalone provisioning form this screenshot used to show has been removed. CommunityBillingsController#provision_platform is now purely an entitlement pre-check + kickoff redirect — it builds a draft Platform linked to the paying community via a new provisioning_community_id column, then redirects here. Name, host URL, time zone, and visibility are now collected by the wizard\'s own platform_identity step instead of a duplicate billing-side form, and the wizard\'s steward_account step (which the old form never had at all) collects steward info that used to require a separate manual step after provisioning.' },
          { title: 'Locale',
            description: 'Unchanged from the staff-facing wizard entry point — see new_platform_setup_welcome for the full wizard walkthrough.' },
          { title: 'Next',
            description: 'The entitlement check already happened once, at this kickoff point, before the redirect — the wizard itself does not re-check billing status per step.' }
        ],
        accessibility_notes: 'Same wizard UI as new_platform_setup_welcome: progress nav uses aria-current="step", locale select has an aria-describedby help text.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.community_billing_path(community, locale: I18n.default_locale)
      click_on I18n.t('better_together.billing.provision_platform_cta', locale: I18n.default_locale, default: 'Provision hosted platform')
      expect(page).to have_css('#new-platform-setup-progress')
      draft = BetterTogether::Platform.order(:created_at).last
      expect(draft.provisioning_community).to eq(community)
    end
  end

  it 'captures the personal billing overview' do
    capture_docs_screenshot(
      'pr_1581_person_billing_overview',
      callouts: [
        { selector: "##{ActionView::RecordIdentifier.dom_id(platform_manager.person, :current_subscription_card)}",
          title: 'Personal subscription', bullets: ['Shows the plan attached to the person as payer.', 'Surfaces portal issues and renewal timing.'] },
        { selector: "##{ActionView::RecordIdentifier.dom_id(platform_manager.person, :sponsored_communities_card)}", title: 'Sponsored communities', bullets: ['Lists communities this person is currently paying for.', 'Provides direct links to each community billing page.'] },
        { selector: "##{ActionView::RecordIdentifier.dom_id(platform_manager.person, :merchant_account_card)}",
          title: 'Merchant account (connected)',
          bullets: ['Session follow-up: the status badge now reflects real state (green here) instead of a hardcoded color regardless of status.', 'The explainer text below correctly describes a connected, active account — a prior bug reused the not-connected copy for both states on the community version of this page.'] }
      ],
      narrative: {
        title: 'Personal billing overview',
        audience: %w[board_member sponsor operator],
        journey_step: 'A person reviews their own billing to see personal access, sponsorship commitments, and any payout onboarding status.',
        callouts: [
          { title: 'Personal subscription',
            description: 'This card is the person-facing equivalent of the community subscription card. It focuses on the individual payer and their current hosted support plan. Session follow-up: the subscription status and merchant account status badges on this page were rendering the raw Stripe/Pay enum value (e.g. "active") instead of the translated label used everywhere else; both now go through the same t() lookup as the community billing page.' },
          { title: 'Sponsored communities',
            description: 'This is the key new accountability surface for sponsorship. A person can now see which communities their payment is supporting and jump directly to those community billing records.' },
          { title: 'Merchant account (connected)',
            description: 'Second-round remediation follow-up: MerchantAccount#status_badge_class replaces a badge that was hardcoded to text-bg-info regardless of status — this account (seeded active/charges+payouts enabled) now shows text-bg-success. This is the only screenshot in the pack seeded with a connected merchant account, so it is also the only one demonstrating the community-side duplicate-i18n-key fix indirectly: person_billings/show.html.erb already used two distinct explainer keys for connected vs not-connected (the bug was community-only), and this connected state confirms the correct copy renders when it should.' },
          { title: 'Personal plans',
            description: 'Personal recurring plans are separated from community plans so the review packet makes clear who each plan is designed to support.' },
          { title: 'Solidarity pricing tier',
            description: 'Session follow-up: same as the community billing page — a plan\'s pricing_tier and solidarity_description are now visible here instead of only in the admin plan editor. As on the community billing page, it falls below the fixed screenshot viewport here; see pr_1581_billing_plan_solidarity_detail for the annotated view.' }
        ],
        accessibility_notes: 'The sponsored communities list and plan table both use stable identifiers and native list/table semantics for deterministic review coverage.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.person_billing_path(platform_manager.person, locale: I18n.default_locale)
      expect(page).to have_css('#person-billing-plans-table')
      expect(page).to have_text('Neighbourhood Pantry')
      expect(page).to have_css('.billing-plan-solidarity-badge', text: 'Solidarity — Small')
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
          bullets: ['Explains the plain-language copy shown to subscribers.', 'Defines hosted access level, support tier, and eligibility.', 'Session follow-up: now also includes pricing tier and solidarity description (see pr_1581_billing_plan_solidarity_detail for a plan where these are non-default).'] }
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
            description: 'Reviewers can see that subscriptions may belong to people or communities, which is central to the multi-owner billing foundation introduced in this PR. Session follow-up: the two new metadata rows push this card below the fixed screenshot viewport on this particular plan, so it no longer has its own callout box here — the card and its content are unchanged, just further down the page than this capture shows.' }
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

  it 'captures the billing plan detail page for a solidarity-tier plan' do
    capture_docs_screenshot(
      'pr_1581_billing_plan_solidarity_detail',
      callouts: [
        { selector: "##{ActionView::RecordIdentifier.dom_id(solidarity_plan, :pricing_tier)}", title: 'Pricing tier',
          bullets: ['Session follow-up: this field existed on every plan already, but the admin plan show page never rendered it — added alongside solidarity description below.'] },
        { selector: "##{ActionView::RecordIdentifier.dom_id(solidarity_plan, :solidarity_description)}", title: 'Solidarity description',
          bullets: ['The admin form\'s own hint text said this is "shown to potential subscribers", but nothing actually rendered it anywhere until this session\'s follow-up.', 'Now shown here for the host operator, and on the subscriber-facing plan card (see the community and personal billing overview screenshots).'] }
      ],
      narrative: {
        title: 'Billing plan detail — solidarity tier',
        audience: %w[operator board_member],
        journey_step: 'A host steward reviews a solidarity-tier plan to confirm the reduced-contribution framing a subscriber will see.',
        callouts: [
          { title: 'Pricing tier',
            description: 'Distinguishes this plan from the standard tier so operators can see at a glance which plans offer reduced-contribution access.' },
          { title: 'Solidarity description',
            description: 'Free-text field explaining who the reduced tier is for. Previously editable in the admin form but invisible everywhere else — this screenshot documents it finally being rendered.' }
        ],
        accessibility_notes: 'Both fields use the same stable dom_id + definition-list pattern as the rest of the metadata card.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.billing_plan_path(solidarity_plan, locale: I18n.default_locale)
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(solidarity_plan, :pricing_tier)}", text: 'Solidarity — Small')
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(solidarity_plan, :solidarity_description)}", text: 'fewer than 20 active members')
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

  it 'captures the community edit billing entry point' do
    capture_docs_screenshot(
      'pr_1581_community_edit_billing_entry_point',
      callouts: [
        { selector: '#community-manage-billing-btn', title: 'Manage billing',
          bullets: ['Jumps from community settings directly to the community billing page.', 'Only shown once the community record is persisted.'] },
        { selector: '#hosted-entitlement-card', title: 'Hosted plan status',
          bullets: ['Repeats the hosted entitlement summary on the edit screen so stewards see billing context while editing settings.'] }
      ],
      narrative: {
        title: 'Community settings — billing entry point',
        audience: %w[board_member community_steward operator],
        journey_step: 'A steward editing community settings needs a direct path to billing without hunting through navigation.',
        callouts: [
          { title: 'Manage billing',
            description: 'This link is the primary cross-link from community administration into the new billing subsystem introduced by this PR.' },
          { title: 'Hosted plan status',
            description: 'Surfacing entitlement status inline on the edit form means a steward changing settings can see, without navigating away, whether hosted access is currently active.' }
        ],
        accessibility_notes: 'The billing link and entitlement card both use stable IDs; the link is a standard focusable anchor styled as a button.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.edit_community_path(community, locale: I18n.default_locale)
      expect(page).to have_css('#community-manage-billing-btn')
      expect(page).to have_css('#hosted-entitlement-card')
    end
  end

  it 'captures the community show billing entry point' do
    capture_docs_screenshot(
      'pr_1581_community_show_billing_entry_point',
      callouts: [
        { selector: '#community-show-manage-billing-btn', title: 'Manage billing',
          bullets: ['Gives stewards with update permission a direct path to billing from the public community page toolbar.'] }
      ],
      narrative: {
        title: 'Community profile — billing entry point',
        audience: %w[community_steward operator],
        journey_step: 'A steward viewing the community profile page needs the same one-click path into billing that exists on the edit screen.',
        callouts: [
          { title: 'Manage billing',
            description: 'This button only renders when the viewer is authorized to update the community, so billing management is not exposed to ordinary members browsing the profile.' }
        ],
        accessibility_notes: 'The button is conditionally rendered based on policy authorization and uses a stable ID for deterministic review coverage.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.community_path(community, locale: I18n.default_locale)
      expect(page).to have_css('#community-show-manage-billing-btn')
    end
  end

  it 'captures the person edit billing entry point' do
    capture_docs_screenshot(
      'pr_1581_person_edit_billing_entry_point',
      callouts: [
        { selector: '#person-manage-billing-btn', title: 'Manage billing',
          bullets: ['Jumps from personal profile settings directly to the person billing page.', 'Only shown once the person record is persisted.'] }
      ],
      narrative: {
        title: 'Profile settings — billing entry point',
        audience: %w[sponsor operator],
        journey_step: 'A person editing their own profile needs a direct path to personal billing, including any communities they sponsor.',
        callouts: [
          { title: 'Manage billing',
            description: 'This is the person-facing equivalent of the community edit billing link, keeping the same cross-link pattern for both billable owner types.' }
        ],
        accessibility_notes: 'The link uses a stable ID and standard focusable anchor markup consistent with the community edit entry point.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.edit_person_path(id: platform_manager.person.slug, locale: I18n.default_locale)
      expect(page).to have_css('#person-manage-billing-btn')
    end
  end

  it 'captures the new billing plan form' do
    capture_docs_screenshot(
      'pr_1581_billing_plan_new_form',
      callouts: [
        { selector: '#billing-plan-form', title: 'New plan form',
          bullets: ['Same field set as the plan editor: pricing, Stripe linkage, and subscriber-facing metadata.', 'Identifier and Stripe Price ID are only editable before the plan is first saved.'] }
      ],
      narrative: {
        title: 'New billing plan',
        audience: %w[operator board_member],
        journey_step: 'A host steward creates a new recurring plan before it can appear in the plan catalog or be selected during checkout.',
        callouts: [
          { title: 'New plan form',
            description: 'This is the creation path for the same form used by the plan editor. Reviewers should confirm identifier and Stripe Price ID stay immutable once a plan is persisted.' }
        ],
        accessibility_notes: 'The form reuses the shared billing plan partial, so the same stable IDs and label associations apply here as on the editor.'
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.new_billing_plan_path(locale: I18n.default_locale)
      expect(page).to have_css('#billing-plan-form')
      expect(page).to have_text('New Billing Plan')
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

    # Session follow-up: beneficiary is now just an alias for billable_owner
    # (see Subscription#beneficiary) — a subscription is always self-funded.
    # Third-party funding is represented by a separate Billing::Sponsorship
    # crediting the beneficiary's own Stripe balance, not by a mismatched
    # billable_owner/beneficiary pair on the subscription itself.
    community_subscription = create(
      :better_together_billing_subscription,
      billing_plan: current_plan,
      billable_owner: community,
      status: 'active',
      sync_source: 'stripe_webhook',
      last_synced_at: 2.hours.ago
    )

    create(
      :better_together_billing_subscription,
      billing_plan: personal_plan,
      billable_owner: platform_manager.person,
      status: 'active',
      sync_source: 'ce_push',
      last_synced_at: 1.hour.ago
    )

    community_sponsorship = create(
      :better_together_billing_sponsorship,
      sponsor: sponsor_community,
      beneficiary: community,
      status: 'active'
    )
    create(
      :better_together_billing_monetary_contribution,
      sponsorship: community_sponsorship,
      amount_cents: 5_000
    )

    create(
      :better_together_billing_sponsorship,
      sponsor: platform_manager.person,
      beneficiary: sponsored_by_person_community,
      status: 'active'
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
