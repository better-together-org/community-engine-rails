# Billing assessment refresh, 24 November 2026

Refreshes [the November assessment](2026-11-billing-assessment.md) (written at `26e283cb8`) against
`feature/billing` at `536cbd5db`. Scope is limited: it records what changed, what was walked in a running app,
and what was not re-checked. It is not a new 64 finding review.

## Verdict against the proposed MVP 1

See [MVP definition](../mvp_definition.md) for the target.

| Gate | Earlier verdict | Now |
|---|---|---|
| Merge to main | GO WITH FIXES | **GO WITH FIXES.** The five named fixes are merged (below). Remaining: migration squash decision is done (#2150); acceptance pass and nav work still open. |
| First production enablement (host only) | NO-GO | **GO WITH FIXES.** The production package items are merged. Needs a configured browser acceptance pass and the operability page. |
| Hosted platform enablement | NO-GO | **Still NO-GO for remote methods and merchant of record** (D8, D9 not built). **Local methods only** are gated by D3a agreements and could be enabled after legal review of the agreement texts, which are draft placeholders. |

## Earlier findings: status at the tip

All fifteen remediation PRs listed in the earlier report are in the tip: #2145, #2148, #2149, #2150, #2152,
#2153, #2155, #2156, #2157, #2159, #2161, #2162, #2163, #2164, #2166 (checked by commit subject; the fixes
themselves were not re-read line by line).

| Finding group | Status |
|---|---|
| CONF-11 seeded agreements | Closed (#2145): spec-order pollution, not a production defect. |
| UX-07 tax report basis, UX-25 PDF dates | Closed (#2148). |
| UX-17, UX-01, UX-02 labels, UX-22 axe gate | Closed (#2149, #2152). |
| CONF-01 and SEC-10 non-host selling | Closed (#2153), and D3a adds the agreement gates. |
| SEC-01, SEC-05, SEC-06, SEC-07, SEC-09 | Closed (#2155, #2159, #2156, #2157). |
| SEC-15, CONF-04, CONF-05 safety-net tests | Added (#2161). Valid signature acceptance still needs a processor gem. |
| PERF-14 billing off not inert, PERF-09 failed event tooling | Closed (#2162, #2163). |
| Postponed Step 4 items | **Still open and not re-checked:** list page indexes, reports and PDFs off the web request, consistent lock order, remaining data model checks, cancel unpaid order, tax preview, resend receipt. |

## Built since the earlier assessment

D0 free plans, D1a buyer hub, D1b and D1c storefront and content blocks, D2 and D2b add-ons, D3 plan change,
D3a hosted billing enablement, D3b refund requests. These were not covered by the earlier review and are
**not yet assessed for security or performance.** Refund requests, plan change and the hosted gates move money
or access and should get the same four reviewer pass before production.

## What the dev app walk showed

Environment: this branch (the tip merged in), dev app on port 3020, billing flag on, demo seed packet
planted, one steward and one buyer. Scripted over HTTP with a session per user. No screen reader, no axe run.

| Check | Result |
|---|---|
| Steward pages: billing hub, plans, sales, subscribers, processor settings, tax registrations, agreement requirements, hosted platforms, refund requests, host dashboard billing tab | All 200. |
| Buyer pages: billing, orders, subscriptions, entitlements, credit | All 200. |
| Buyer on steward pages | Redirected (302); host billing tab 404. Correct. |
| Catalog `/billing/catalog` | Lists four demo plans with prices and buttons. |
| Checkout page for each plan | Renders; add-on checkbox, method choices and tax lines show (HST 15% on CA$100 gives CA$115 for a Newfoundland address). |
| Free plan checkout | Succeeds, redirects to a Paid order. Resolves story 0.5. |
| Paid cash checkout | Validation works (stale total and missing address are refused with clear messages). **Not completed:** the scripted form did not satisfy the address fields. Needs a browser. |
| Subscription page | Shows renewal method with "Pay renewals by" and a Change plan link. |
| Hosting plan page on the host | 404, by design (hosted platforms only). Not walked. |
| Anonymous catalog | Redirected to sign in because the dev platform is private. **Not verified** as public. |

## Findings from this pass

1. **No explanation when billing is off or half configured.** Gated pages answer 404. A steward cannot tell
   why. Add the readiness explanation page (already planned).
2. **Hosting plan and hosted billing pages are unreachable on the host**, so they could not be seen in this
   walk. They need a hosted platform fixture in the dev data for acceptance.
3. **Checkout address entry is a multi-field form with a select**; the scripted walk could not complete it,
   which is a signal worth checking for keyboard and screen reader flow in the browser pass.
4. **Billing menu has two dropdowns in the host area.** The contrast sweep could only measure the Host one
   (opening Billing while Host is open is intercepted). Billing menu colours are not contrast checked.

## Not re-checked

Line level confirmation of the earlier fixes, performance, concurrency, the processor gem track (B0 to B7),
and the four translations beyond key presence.
