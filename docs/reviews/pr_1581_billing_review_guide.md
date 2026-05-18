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

## The six screenshots to review first

Each screenshot is committed in `docs/screenshots/review/pr-1581/` in both desktop and mobile variants.

1. `pr_1581_community_billing_overview`
   This is the best single page to understand the new system. It shows hosted entitlement, current payer, merchant onboarding status, webhook trouble alerts, and checkout options.

2. `pr_1581_provision_hosted_platform`
   This shows that platform creation is now gated by an active hosted entitlement rather than an informal manual process.

3. `pr_1581_person_billing_overview`
   This explains the new sponsorship model. A person can now see their own plan and the communities they are financially supporting.

4. `pr_1581_billing_plans_index`
   This is the host operator inventory of all recurring plans currently available for launch.

5. `pr_1581_billing_plan_detail`
   This shows how a plan's subscriber-facing promises are stored: summary text, benefits, hosted access level, support tier, and who is allowed to pay.

6. `pr_1581_billing_plan_editor`
   This shows how host stewards configure the plan catalog that drives the new billing pages.

## The three diagrams to review

Source files live in `docs/diagrams/source/`. Review copies live in `docs/diagrams/review/pr-1581/`.

### Billing object and data model

`pr_1581_billing_object_data_model`

Read this first if the data model feels confusing. The most important concept is that:

- the payer is the record being charged
- the beneficiary is the record receiving hosted service

They can be the same entity, but they do not have to be.

### Checkout and entitlement flow

`pr_1581_billing_checkout_and_entitlement_flow`

This shows how a billing page action turns into a Stripe checkout session, then into local subscription state, then into an active or inactive hosted entitlement.

### Stripe Connect merchant flow

`pr_1581_stripe_connect_merchant_flow`

This diagram is separate because payout onboarding is not the same as hosted billing. A community may have hosted service before it is ready to receive payouts.

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

## Remaining limits to keep in mind

- this PR still uses Stripe as the only active billing provider in the launch path
- one-time payment plans remain intentionally outside the current hosted launch path
- merchant onboarding visibility is present here, but full downstream commerce flows are still future work
