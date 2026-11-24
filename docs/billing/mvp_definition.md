# Billing MVP definition (proposed, for approval)

Status: proposed 2026-11-24. Nothing here is decided until the project owner approves it. Until then the
stories doc is the only written scope, and "MVP" has no fixed meaning.

This page fixes what "the billing MVP" means, so a verdict on the branch can be checked against it. It uses the
story ids from [user stories and coverage](user_stories_and_coverage.md) and the D steps in its stack.

## Three possible targets

| Target | Meaning | Steps needed | Status at `536cbd5db` |
|---|---|---|---|
| **MVP 1: host sells to its own people** | The host platform sells free and paid plans and add-ons, takes offline payments, taxes them, and buyers manage their own account. | A-chunks, D0, D1a to D1c, D2, D2b, D3, D3b | Built. Needs acceptance (below). |
| **MVP 2: hosted platforms self-serve** | A prospect buys a hosting tier and gets a working platform without an operator. Hosted platforms can sell with local methods. | MVP 1 plus D3a, D4, D4a, D8 | Partial. D3a is built; D4 provisioning, D4a tasks and D8 processors are not. |
| **MVP 3: co-op and association** | Shares, donations, event fees, sub-community plans. | MVP 2 plus D5, D6, D7, D10 | Not started. |

Recommendation: call **MVP 1** the billing MVP and the merge target for `feature/billing`. MVP 2 and 3 are
follow-on releases. Hosted platform billing stays off until MVP 2 work lands (it already fails closed).

## MVP 1 exit criteria

A story counts only when it works in a browser on a clean install, not just in specs.

| Area | Stories | Criterion |
|---|---|---|
| Plans | 0.1, 0.2, 0.3, 0.4 | A steward defines free and paid plans with storage and feature grants, and sees usage. |
| Free plan | 0.5, 3.1 | A $0 plan checks out without a payment method and grants its entitlement. |
| Storefront | 1.1 (list), 1.2, P12 | A visitor sees listed plans and prices and reaches checkout from a button. |
| Checkout | 1.10, 2.9, 2.11, 2.12 | Add-ons, agreements, tax lines, offline methods, receipts and the steward confirmation queue work. |
| Buyer account | 4.1 to 4.7, 4.9, 4.11, 4.12 | A buyer finds Billing in the menu, sees orders, subscriptions, credit and access, cancels, resumes, changes plan, changes renewal method, and requests a refund. |
| Steward back office | 4.8, 0.9, 1.15 | Stewards review refunds, record walk-up sales, and report tax and revenue. |
| Safety | | The remediation findings from the first assessment are fixed and covered by specs (done, PRs #2145 to #2166). Billing off is inert. Non-host platforms cannot sell. |
| Operability | | A steward on a new install can tell why billing is off and what to configure (readiness checklist, a clear page instead of a bare 404). |
| Docs | | Screenshots, diagrams, four locales, and DOM contracts for every changed view. uk, es and fr text reviewed. |

## Out of MVP 1 on purpose

Provisioning from a paid order, subdomain picker, custom domain add-on, task system, donations, shares, event
fees, per-platform processors, merchant of record, community-sold plans, guest checkout, comparison page,
order filters, address editor and notification preferences. Each is listed in the stories doc with its D step.

## Open items against MVP 1

1. **Browser acceptance pass.** Core buyer journey passes in CI-style browser specs; a pass on a configured
   instance by a person is still open (see the [assessment refresh](assessments/2026-11-billing-assessment-refresh.md)).
2. ~~Billing not configured page~~ Built: a host steward sees what is still to set up (same 404 status, everyone else
   sees the plain 404), and the readiness checklist now checks that a worker is taking the billing queue.
3. **Navigation**: the billing menu and route-name list changes in this PR chain, and the migration that adds
   missing items to existing host apps.
4. **Translations** for es, fr and uk are unreviewed.
5. **Stale trackers**: tick #1581 and keep this file and the stories doc current.
6. **Anonymous storefront** was not exercised (the dev platform is private). Verify on a public platform.
7. **Buyer flows in a browser** now pass: paid checkout, anonymous visitor to sign-in and back to checkout, new
   address with country and province pickers, cancel and resume, plan change and withdraw, refund request. Still
   to do: mobile width, renewal, a public-platform catalog check by a person.
