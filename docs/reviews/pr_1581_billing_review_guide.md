# PR 1581 Billing Review Guide

This guide is for reviewers who want to understand the billing changes in PR 1581 without running a development server.

## What changed

PR 1581 introduces the first complete hosted billing foundation for Community Engine:

- communities can have a hosted recurring plan
- people can have their own hosted recurring plan
- a person or another community can sponsor a community's hosted plan
- hosted billing ownership and Stripe Connect payout onboarding are tracked separately
- webhook failures, ignored events, and dead-lettered events are now visible on the billing pages
- an active hosted entitlement can unlock hosted platform provisioning for a community

## The main stakeholder questions this PR answers

### For a community steward

- Is this community currently paid up for hosted service?
- Who is paying right now?
- If the wrong person or community is paying, how do we take billing over cleanly?
- Can we provision a hosted platform yet?

### For an individual sponsor

- What am I paying for personally?
- Which communities am I sponsoring right now?
- Can I see billing problems without digging through logs?

### For host operators

- Which plans exist and who can buy them?
- Are webhook failures visible and replayable?
- Is a Stripe Connect merchant account payout-ready?

## The seven screenshots to review first

Each screenshot is committed in [docs/screenshots/review/pr-1581](../screenshots/review/pr-1581/) in both desktop and mobile variants. Three of these (marked **updated**) were recaptured after the session follow-up described below — see that section for what changed in each.

1. `pr_1581_community_billing_overview` — **updated**
   This is the best single page to understand the new system. It shows hosted entitlement, current payer, merchant onboarding status, webhook trouble alerts, and checkout options.

   Files:
   [desktop PNG](../screenshots/review/pr-1581/pr_1581_community_billing_overview-desktop.png) ·
   [mobile PNG](../screenshots/review/pr-1581/pr_1581_community_billing_overview-mobile.png) ·
   [desktop narrative](../screenshots/review/pr-1581/pr_1581_community_billing_overview-desktop.narrative.yml) ·
   [mobile narrative](../screenshots/review/pr-1581/pr_1581_community_billing_overview-mobile.narrative.yml)

   ![Community billing overview screenshot](../screenshots/review/pr-1581/pr_1581_community_billing_overview-desktop.png)

2. `pr_1581_provision_hosted_platform`
   This shows that platform creation is now gated by an active hosted entitlement rather than an informal manual process.

   Files:
   [desktop PNG](../screenshots/review/pr-1581/pr_1581_provision_hosted_platform-desktop.png) ·
   [mobile PNG](../screenshots/review/pr-1581/pr_1581_provision_hosted_platform-mobile.png) ·
   [desktop narrative](../screenshots/review/pr-1581/pr_1581_provision_hosted_platform-desktop.narrative.yml) ·
   [mobile narrative](../screenshots/review/pr-1581/pr_1581_provision_hosted_platform-mobile.narrative.yml)

   ![Hosted platform provisioning screenshot](../screenshots/review/pr-1581/pr_1581_provision_hosted_platform-desktop.png)

3. `pr_1581_person_billing_overview` — **updated**
   This explains the new sponsorship model. A person can now see their own plan and the communities they are financially supporting.

   Files:
   [desktop PNG](../screenshots/review/pr-1581/pr_1581_person_billing_overview-desktop.png) ·
   [mobile PNG](../screenshots/review/pr-1581/pr_1581_person_billing_overview-mobile.png) ·
   [desktop narrative](../screenshots/review/pr-1581/pr_1581_person_billing_overview-desktop.narrative.yml) ·
   [mobile narrative](../screenshots/review/pr-1581/pr_1581_person_billing_overview-mobile.narrative.yml)

   ![Person billing overview screenshot](../screenshots/review/pr-1581/pr_1581_person_billing_overview-desktop.png)

4. `pr_1581_billing_plans_index`
   This is the host operator inventory of all recurring plans currently available for launch.

   Files:
   [desktop PNG](../screenshots/review/pr-1581/pr_1581_billing_plans_index-desktop.png) ·
   [mobile PNG](../screenshots/review/pr-1581/pr_1581_billing_plans_index-mobile.png) ·
   [desktop narrative](../screenshots/review/pr-1581/pr_1581_billing_plans_index-desktop.narrative.yml) ·
   [mobile narrative](../screenshots/review/pr-1581/pr_1581_billing_plans_index-mobile.narrative.yml)

   ![Billing plans index screenshot](../screenshots/review/pr-1581/pr_1581_billing_plans_index-desktop.png)

5. `pr_1581_billing_plan_detail` — **updated**
   This shows how a plan's subscriber-facing promises are stored: summary text, benefits, hosted access level, support tier, and who is allowed to pay.

   Files:
   [desktop PNG](../screenshots/review/pr-1581/pr_1581_billing_plan_detail-desktop.png) ·
   [mobile PNG](../screenshots/review/pr-1581/pr_1581_billing_plan_detail-mobile.png) ·
   [desktop narrative](../screenshots/review/pr-1581/pr_1581_billing_plan_detail-desktop.narrative.yml) ·
   [mobile narrative](../screenshots/review/pr-1581/pr_1581_billing_plan_detail-mobile.narrative.yml)

   ![Billing plan detail screenshot](../screenshots/review/pr-1581/pr_1581_billing_plan_detail-desktop.png)

6. `pr_1581_billing_plan_solidarity_detail` — **new**
   The same admin plan detail page as above, but for a plan with a non-standard pricing tier — shows the two metadata fields (pricing tier, solidarity description) that existed on every plan already but were never rendered anywhere until this session's follow-up.

   Files:
   [desktop PNG](../screenshots/review/pr-1581/pr_1581_billing_plan_solidarity_detail-desktop.png) ·
   [mobile PNG](../screenshots/review/pr-1581/pr_1581_billing_plan_solidarity_detail-mobile.png) ·
   [desktop narrative](../screenshots/review/pr-1581/pr_1581_billing_plan_solidarity_detail-desktop.narrative.yml) ·
   [mobile narrative](../screenshots/review/pr-1581/pr_1581_billing_plan_solidarity_detail-mobile.narrative.yml)

   ![Billing plan solidarity detail screenshot](../screenshots/review/pr-1581/pr_1581_billing_plan_solidarity_detail-desktop.png)

7. `pr_1581_billing_plan_editor`
   This shows how host stewards configure the plan catalog that drives the new billing pages.

   Files:
   [desktop PNG](../screenshots/review/pr-1581/pr_1581_billing_plan_editor-desktop.png) ·
   [mobile PNG](../screenshots/review/pr-1581/pr_1581_billing_plan_editor-mobile.png) ·
   [desktop narrative](../screenshots/review/pr-1581/pr_1581_billing_plan_editor-desktop.narrative.yml) ·
   [mobile narrative](../screenshots/review/pr-1581/pr_1581_billing_plan_editor-mobile.narrative.yml)

   ![Billing plan editor screenshot](../screenshots/review/pr-1581/pr_1581_billing_plan_editor-desktop.png)

## The four diagrams to review

Source files live in [docs/diagrams/source](../diagrams/source/). Review copies live in [docs/diagrams/review/pr-1581](../diagrams/review/pr-1581/).

### Billing object and data model

Files:
[review PNG](../diagrams/review/pr-1581/pr_1581_billing_object_data_model.png) ·
[review SVG](../diagrams/review/pr-1581/pr_1581_billing_object_data_model.svg) ·
[review Mermaid](../diagrams/review/pr-1581/pr_1581_billing_object_data_model.mmd) ·
[source Mermaid](../diagrams/source/pr_1581_billing_object_data_model.mmd)

Read this first if the data model feels confusing. The most important concept is that:

- the payer is the record being charged
- the beneficiary is the record receiving hosted service

They can be the same entity, but they do not have to be.

![Billing object and data model diagram](../diagrams/review/pr-1581/pr_1581_billing_object_data_model.png)

### Checkout and entitlement flow

Files:
[review PNG](../diagrams/review/pr-1581/pr_1581_billing_checkout_and_entitlement_flow.png) ·
[review SVG](../diagrams/review/pr-1581/pr_1581_billing_checkout_and_entitlement_flow.svg) ·
[review Mermaid](../diagrams/review/pr-1581/pr_1581_billing_checkout_and_entitlement_flow.mmd) ·
[source Mermaid](../diagrams/source/pr_1581_billing_checkout_and_entitlement_flow.mmd)

This shows how a billing page action turns into a Stripe checkout session, then into local subscription state, then into an active or inactive hosted entitlement.

![Checkout and entitlement flow diagram](../diagrams/review/pr-1581/pr_1581_billing_checkout_and_entitlement_flow.png)

### Stripe Connect merchant flow

Files:
[review PNG](../diagrams/review/pr-1581/pr_1581_stripe_connect_merchant_flow.png) ·
[review SVG](../diagrams/review/pr-1581/pr_1581_stripe_connect_merchant_flow.svg) ·
[review Mermaid](../diagrams/review/pr-1581/pr_1581_stripe_connect_merchant_flow.mmd) ·
[source Mermaid](../diagrams/source/pr_1581_stripe_connect_merchant_flow.mmd)

This diagram is separate because payout onboarding is not the same as hosted billing. A community may have hosted service before it is ready to receive payouts.

![Stripe Connect merchant flow diagram](../diagrams/review/pr-1581/pr_1581_stripe_connect_merchant_flow.png)

### Sponsor authorization scope — **new**

Files:
[review PNG](../diagrams/review/pr-1581/pr_1581_sponsor_authorization_scope.png) ·
[review SVG](../diagrams/review/pr-1581/pr_1581_sponsor_authorization_scope.svg) ·
[review Mermaid](../diagrams/review/pr-1581/pr_1581_sponsor_authorization_scope.mmd) ·
[source Mermaid](../diagrams/source/pr_1581_sponsor_authorization_scope.mmd)

Added in this session's follow-up. Contrasts the sponsor-candidate list before and after tightening `CommunityBillingsController`'s authorization — see the follow-up section below.

![Sponsor authorization scope diagram](../diagrams/review/pr-1581/pr_1581_sponsor_authorization_scope.png)

## What the review comments in this PR were about

The unresolved review comments focused on six real risk areas:

- preventing webhook-driven Stripe sync loops
- keeping local plan activation state aligned with Stripe products
- choosing the current subscription deterministically in the database
- moving hard-coded fallback copy into locale files
- failing closed when no host platform is available for plan authorization
- updating operator docs so they match the billing behavior now present in the code

Those issues are now addressed in the code and in the operator documentation.

## Additional review findings from the implementation pass

Two broader issues also needed correction to make the sponsorship model reliable:

1. Billing ownership changes were not being persisted all the way through to the associated `Pay::Subscription`.
   The fix was to autosave the associated Pay subscription and reapply pending virtual owner and beneficiary assignments before validation.

2. Billing pages needed stakeholder-facing accountability surfaces.
   The fix was to show sponsored communities on personal billing pages, show sponsorship takeover actions on community billing pages, and show webhook problem states directly in the billing UI.

## Session follow-up: UX, accessibility, and solidarity-tier changes

A separate stakeholder review (screens only, no code) found that the billing pages read as cold and alien to an average non-technical user — internal engineering language leaking into subscriber-facing copy, an untranslated status bug, a missing ARIA role, and an authorization gap in the sponsor-candidate list. Two follow-up commits addressed this:

**Commit `b01426419` — copy, i18n, and authorization fixes**

- `sponsored_subscription_notice` and the three `takeover_as_*` locale strings (en/es/fr/uk) no longer say "Phase 1", "replacement checkout", or "transfer workflow" — see the current copy in the community billing overview screenshot above. es/fr were drafted with local-model assistance and hand-reviewed; a native-speaker pass is still recommended before merge.
- `person_billings/show.html.erb` was rendering `@billing_subscription.status` and `@merchant_account.status` raw instead of through `t(...)`, unlike the community billing page. Both now translate correctly — compare the "Active" badges in the person billing overview screenshot.
- `_billing_event_alerts.html.erb`'s alert banners now carry `role="alert"` so screen readers announce dead-letter/repeated-failure/unresolved-drift states. This has no visual effect, so it isn't visible in any screenshot.
- `CommunityBillingsController`'s sponsor-candidate list (`@sponsoring_communities`, `sponsoring_communities_by_slug`) is now scoped to communities the current user can `policy(...).update?` on — the same gate `portal_billable_owner` already applied to billing-portal access — instead of every community visible under `policy_scope`. See the new "Sponsor authorization scope" diagram above.
  **Reviewer note:** the community billing overview screenshot was captured logged in as a platform manager, whose blanket `platform_manager?` authority satisfies `update?` for every community — so that screenshot still shows a long candidate list. That's expected: platform managers are meant to see everything. The fix narrows the list for stewards who only manage specific communities, which this screenshot doesn't demonstrate on its own.

**Commit `dfc403611` — surface solidarity pricing tiers on subscriber-facing plan cards**

- `Billing::Plan` already had `pricing_tier` (`standard`/`solidarity_small`/`solidarity_medium`/`solidarity_premium`) and a per-plan `solidarity_description`, both editable in the admin plan form — whose own hint text said the description is "shown to potential subscribers" — but neither was rendered anywhere a subscriber could actually see it.
- The shared `_billing_plan_details` partial (used by both community and person billing pages) now shows a solidarity badge and description when a plan's tier is non-standard. See the "Harbour Solidarity" row in the person billing overview screenshot, and the dedicated `pr_1581_billing_plan_solidarity_detail` screenshot for the same fields on the admin side, which also had the gap.

## Recommended review order

1. Read this guide.
2. Review the community billing overview screenshot.
3. Review the person billing overview screenshot.
4. Review the checkout and entitlement flow diagram.
5. Review the plan detail and plan editor screenshots.
6. Review the merchant flow diagram if payout onboarding matters to your role.

## Validation completed for this packet

- focused billing model, service, request, and job specs passed
- DOM contract coverage added for the new billing review anchors
- screenshot capture spec added for the new and modified billing views
- Mermaid source files added for the billing object model and key flows
- session follow-up: rubocop, brakeman, and i18n-tasks health clean on both follow-up commits; targeted request/DOM-contract specs green (62 examples, including new solidarity-tier and takeover-copy assertions); doc screenshot spec re-run clean (11 examples) after adding the solidarity plan fixture and the new plan-detail screenshot

## Remaining limits to keep in mind

- this PR still uses Stripe as the only active billing provider in the launch path
- one-time payment plans remain intentionally outside the current hosted launch path
- merchant onboarding visibility is present here, but full downstream commerce flows are still future work
