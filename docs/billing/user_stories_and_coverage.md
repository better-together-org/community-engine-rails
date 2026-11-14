# Billing user stories and coverage

What the billing feature has to do for the people who use it, which of those stories the code supports
today, and what has to be added. Written against `feature/billing` at `2cd8545d4` (tax reports merged,
#2127). Statuses are read from code and docs, not from running specs; items marked U are unverified.

Related: [Hosted billing roadmap](hosted_billing_roadmap.md), [Plan catalog](plan_catalog.md),
[Entitlements and allowances](entitlements_and_allowances.md), [Subscriptions and renewals](subscriptions_and_renewals.md),
[Orders and payments](orders_and_payments.md), [Tax](tax.md).

## The headline

The billing backend is deep: plans, orders, split payments, offline methods, tax, entitlements, quotas,
renewals. The buyer-facing front half is missing.

- No public plan catalog, pricing page, comparison or plan detail. The `plans/*` views are steward only
  (`manage_billing?` needs `manage_platform`).
- No cart and no Buy, Subscribe or Donate button anywhere. Nothing links to `/billing/checkout/new?plan_id=`;
  a buyer has to type the URL.
- None of the 23 CMS content blocks touches billing. `CallToActionBlock` is generic.
- Checkout takes one plan (`CheckoutsController#set_plan`, `purchasables: [@plan]`). `Orders::Place` accepts
  many lines, so the data layer is ready and the UI is not. No bundle or add-on concept.
- `Billing::Plan` is the only `Purchasable`. No tickets, donations, deposits or products.
- Checkout never passes `on_behalf_of` or a beneficiary, so a person cannot buy for a community from the UI.
- The buyer's account area exists but cannot be found and cannot do the key actions. Routes and views exist
  for order history (`/billing/orders`), subscriptions (`/billing/subscriptions`), access and usage
  (`/billing/entitlements`) and store credit (`/billing/credit`). The only billing navigation items are the
  three admin ones (`billing-plans`, `billing-processor-settings`, `billing-sales`). Missing actions: change
  plan, request a refund, change payment method, one place for receipts. Refunds are steward only
  (`SaleRefundsController`); there is no refund request.

## Other structural gaps

1. **Only the host platform can sell.** `OwnerPolicy#manage_billing?` is false unless the owner is a Platform,
   and `Configuration.context_for` is environment backed and host only. A hosted platform has billing off.
   Community or person sold plans have the data shape (`seller`) but no route, UI, permission, entitlements or
   CE renewals.
2. **Nothing connects a purchase to provisioning.** `TenantPlatformProvisioningService` is called only by a
   rake task and host operator wizards. The registered entitlement kinds are `membership_role`,
   `feature_access` and `quota_allowance`. The `hosted_platform` grant (banner, block new capacity, read only
   suspension) is documented as not built.
3. **A hosted platform's owner cannot see or manage their own hosting plan.** The platform page has only a
   quota grants link.
4. **No plan change.** Mid-subscription changes are unsupported (cancel and resubscribe). Terms are
   immutable. No proration. Only a steward `move_to_current_price`.
5. **No donations and no refundable share.** No open amount, no recurring donation, no share ledger, no
   refund on cancel.
6. **No event registration fees.** `Event#registration_url` is a free URL. No price, capacity, ticket model
   or tie to `Order`. `ticket` is only an order purpose label.
7. **Custom domain is a host operator form only.** `PlatformDomain` does not distinguish subdomain from custom
   domain, and there is no DNS verification, TLS step or billing link.
8. **A separate app and database is absent.** The docs say shared schema is the model.
9. **No plan level trial, price discount, metering or bundle.**
10. **Free plans are unverified.** `amount_cents >= 0` validates; a $0 checkout, order and entitlement path
    was not confirmed.
11. **Quotas are not the blocker.** Storage and AI token allowances from plans work, with community pooling
    and enforcement modes off, shadow (default), soft and hard.

## Personas

| ID | Persona | Notes |
|---|---|---|
| P1 | Host operator (BTS steward) | Sells hosting plans, manages quotas and tax. |
| P2 | Prospect | Visitor deciding on a hosted platform; may have no account. |
| P3 | Hosted platform owner | Steward of a platform that runs on the host. |
| P4 | Community organizer | Member of a host community who wants a platform for it. |
| P5 | Association member | Annual member, conference and AGM attendee. |
| P6 | Co-op member (free or paid) | Holds a common share, uses member only areas. |
| P7 | Sub-community organizer | Runs a community with its own tiers and content. |
| P8 | Donor | One off or recurring, may not be a member. |
| P9 | Finance admin or treasurer | Reconciles, refunds shares, reports tax. |
| P10 | Content editor | Builds pages and places commerce blocks. |
| P11 | BTS operator | Fulfils the separate instance tier. |
| P12 | Visitor | Anonymous reader of public pages and prices. |

Coverage: **B** built and merged, **P** partial (backend only or with limits), **M** missing,
**U** unverified (needs a spec or a manual check).

## Scenario 0: the host offers free and paid provisioning and quotas

| # | Story | Cov | Today / needs |
|---|---|---|---|
| 0.1 | As P1 I define free and paid plans with storage and AI quota allowances. | B | Plans, `quota_allowance` grants, interval, currency, tax category, translated text. |
| 0.2 | As P1 I grant feature access (alpha and beta gates) and roles that carry no `manage_*`. | B | `feature_access`, `membership_role` handlers. |
| 0.3 | As P1 I override quota for one person or platform without a plan. | B | `QuotaGrant`, platform quota grants UI. |
| 0.4 | As P1 I choose enforcement per quota type and see usage. | B | `/billing/allowances`. |
| 0.5 | As P1 I offer a free hosting tier. | U | $0 plan validates; $0 checkout, order and entitlement unconfirmed. |
| 0.6 | As P1 a paid order provisions a platform and its steward automatically. | M | `platform_provisioning` entitlement kind calling `TenantPlatformProvisioningService` from a job. |
| 0.7 | As P1 a lapsed hosted platform goes read only, not deleted, and I see over limit platforms. | M | `hosted_platform` grant, suspension, over limit notices (documented, unbuilt). |
| 0.8 | As P1 I see which hosted platforms are on which plan and their usage. | P | Subscribers list exists; no per platform hosting view. |
| 0.9 | As P1 I report tax and revenue per plan. | B | Tax reports on the metrics dashboard. |

## Scenario 1: hosted platform tiers

Tier A: subdomain on the host domain, shared database, custom domain as a paid extra. Tier B: custom domain
included, more storage and features. Tier C: a separate app and database, the platform is its own host.

| # | Story | Cov | Today / needs |
|---|---|---|---|
| 1.1 | As P2 I compare tiers A, B and C on a public page (price, domain, storage, AI, features). | M | Catalog and comparison page. Plan metadata (`pricing_tier`, `hosted_access_level`) exists but is not shown or enforced. |
| 1.2 | As P2 I start checkout from a tier card without typing a URL. | M | Buy button and public plan detail. |
| 1.3 | As P2 I sign in or sign up in the middle of checkout and keep my selection. | P | Checkout needs sign in; no return to plan. |
| 1.4 | As P4 I check out as a member of a community and the new platform's community is my community. | M | Checkout lacks `on_behalf_of`; provisioning must link the existing community as primary (the service currently creates one). |
| 1.5 | As P2 I choose my subdomain at checkout and see that it is available. | M | Subdomain picker with validation, reserved names and uniqueness. |
| 1.6 | As P3 I add a custom domain as a paid add-on to tier A. | M | Add-on line item, `PlatformDomain` creation, DNS verification, TLS. |
| 1.7 | As P3 tier B includes the custom domain and raised quotas without extra steps. | P | Quotas work; domain entitlement kind missing. |
| 1.8 | As P3 I see my hosting plan, renewal date, usage, invoices and payment method. | M | Platform "Plan and usage" page reusing subscriptions and entitlement meters. |
| 1.9 | As P3 I upgrade or downgrade with proration and my features and quotas change with it. | M | Plan change service: move the term, prorate, resync entitlements, block a downgrade that is over limits. |
| 1.10 | As P3 I buy extra storage or AI tokens as add-ons. | M | Add-on plans with `quota_allowance` grants and multi-line checkout. |
| 1.11 | As P3 I cancel and my platform stays readable through the paid period, then read only. | P | Cancel works; suspension missing. |
| 1.12 | As P3 on tier C I request and receive a separate instance that is its own host. | M | Operator task (1.13), manual fulfilment first. |
| 1.13 | As P11 I receive a provisioning task when tier C is paid, with order, plan and requested domain on it, and I assign, comment, set due dates and mark it done. | M | Needs a project and task system for BTS operators (G23). Billing creates the task; the task system is a general feature. |
| 1.13a | As P3 I see the status of my instance request (queued, in progress, ready) and a contact point. | M | Task status shown on the hosting plan page. |
| 1.14 | As P3 I move from tier A to B or B to C keeping content and domain. | M | Documented migration path and export and import; mostly outside billing. |
| 1.15 | As P1 I invoice in several currencies with tax. | B | Multi currency, tax by place of supply, PDF invoices. |

## Scenario 2: association with an annual membership paired with a conference and AGM

| # | Story | Cov | Today / needs |
|---|---|---|---|
| 2.1 | As P9 on a hosted platform I can sell my own plans with my own payment accounts. | M | Per platform billing, gated by the agreements in "Hosted billing enablement". |
| 2.1a | As P9 I accept the hosted platform billing agreement, then the hosted local billing agreement, and enable cash, cheque and e-Transfer with no processor account. | M | Agreement gate, `ProcessorSetting` for the hosted platform. |
| 2.1b | As P9 I connect my own processor account for remote methods after accepting the hosted platform billing agreement. | M | Per platform credentials, webhooks, test connection. |
| 2.1c | As P9 I choose the host as merchant of record, after accepting the merchant onboarding agreement, so I need no processor account. | M | MoR mode: host collects, pays out, fee split, host as tax registrant for those sales. |
| 2.1d | As P1 I see which hosted platforms accepted which agreements and which billing modes are on, and I can pause a platform's billing. | M | Enablement status page and audit trail. |
| 2.2 | As P5 I buy an annual membership that renews yearly. | P | Annual plans and CE renewals work for a platform's own plans; blocked on 2.1 only. |
| 2.3 | As P5 I register for the conference and AGM and pay the fee. | M | Event fee, capacity, ticket types, registration tied to `Order`. |
| 2.4 | As P5 I pay membership and registration in one order. | M | Multi-line checkout, plus a rule that one line carries the other's entitlement. |
| 2.5 | As P5 the membership renews on its own anniversary even when bought with the registration. | P | A subscription started from a paid order exists (`Subscriptions::Start`); the bundled case needs a spec. |
| 2.6 | As P5 the member price applies to registration while my membership is active. | M | Price rule by entitlement. |
| 2.7 | As P9 I know who is a member in good standing on the AGM date. | P | Entitlement state exists; needs an as of date roster export. |
| 2.8 | As P9 I can comp or discount a registration. | P | Promotions grant store credit only; no price discount or comp. |
| 2.9 | As P5 I receive a receipt and invoice with the tax breakdown per line. | B | Order documents with tax lines. |
| 2.10 | As P9 I refund a registration without ending the membership. | P | Refunds are per payment with pro rated tax; needs line level refund and no entitlement change. |
| 2.11 | As P5 I accept membership and event terms before paying. | B | Agreement requirements; event and ticket targets are listed as future. |
| 2.12 | As P5 I renew by cheque or e-Transfer and an admin confirms. | B | Offline methods and queue. |
| 2.13 | As P5 I get reminders before renewal and before the conference. | P | Renewal reminders built; event reminders not tied to payment. |

## Scenario 3: co-op with sub-communities, donations and a common share

| # | Story | Cov | Today / needs |
|---|---|---|---|
| 3.1 | As P6 I join free and get a community role. | U | $0 plan, entitlement and membership grant, plus an approval flow. |
| 3.2 | As P6 I join as a paid member and the membership does not expire until I cancel. | P | Recurring with no end exists; needs an "until cancelled" display and a free to paid upgrade (1.9). |
| 3.3 | As P6 my membership grants member only content and community areas. | P | `membership_role`, `feature_access` and the `community` privacy level work; needs a scoping spec and a "members only, join here" message. |
| 3.4 | As P6 I hold a common share that is not income and is not taxable. | M | Share line item in a non taxable category, plus a share ledger recorded as a liability. |
| 3.5 | As P9 a share is refunded on cancellation after board approval. | M | Withdrawal workflow: request, manual board approval, refund to the original method or store credit, ledger entry, entitlement revoked. Distinct from a payment refund. |
| 3.6 | As P9 I report total share capital and shares by member. | M | Share ledger report. |
| 3.7 | As P8 I make a one off donation of a chosen amount, with suggested amounts. | M | Donation purchasable, custom amount, minimum and suggestions. |
| 3.8 | As P8 I set up a recurring donation and change or stop it. | M | Open amount recurring plan; terms already store `unit_amount_cents`, so this may be small. |
| 3.9 | As P8 donations are non taxable and my receipt says so. | P | Tax category supports it; receipt wording needs writing. Charitable receipts are not required (G24 is a future spec). |
| 3.10 | As P8 I donate without becoming a member, with or without an account. | M | Guest checkout absent. |
| 3.11 | As P7 my community has its own free and paid memberships and scoped posts. | P | Per community roles and scoped content exist; community sold plans, seller entitlements and a community billing permission are missing. |
| 3.12 | As P7 my sub-community is an ordinary community on the co-op's platform with its own plans, members and content. | P | Decided: no hierarchy and no association with the host community beyond platform scoping. Missing only community sold plans (3.11). On the co-op's own instance (tier C) sub-communities are ordinary communities on that platform. |
| 3.13 | As P7 a sub-community's money reports separately or goes to its own account. | M | Seller scoped tax and processor settings exist; connected accounts and fee splits missing. |
| 3.14 | As P6 I see my share, memberships, donations and receipts in one place. | P | Pieces exist; no share or donation view. |
| 3.15 | As P9 I record a member who paid cash at a meeting. | B | Walk-up sale. |
| 3.16 | As P9 I charge the share and the membership fee as separate lines in one join order. | M | Same multi-line need as 2.4. |

## Scenario 4: the buyer's account area

| # | Story | Cov | Today / needs |
|---|---|---|---|
| 4.1 | As a buyer I find Billing in my account menu and land on one page with active plans, renewals, recent orders, credit and access. | M | Pages exist separately; needs menu entries and a hub. |
| 4.2 | As a buyer I see my order history with status, date, amount, tax and receipt download, and filter by status or year. | P | `/billing/orders` and documents exist; no filters, no cross order receipts, no menu link. |
| 4.3 | As a buyer I see my active plans, who each one covers (me, my community, my platform), the next renewal and the amount. | P | Subscriptions and entitlements pages exist; beneficiary and renewal detail need checking. |
| 4.4 | As a buyer I cancel at period end and resume before it ends. | B | CE renewed subscriptions. Processor renewed ones have no payer screen in core. |
| 4.5 | As a buyer I upgrade, downgrade or switch interval. | M | Same as 1.9. |
| 4.6 | As a buyer I change the payment method on an existing subscription. | P | Checkout offers "renew with"; terms are immutable and there is no change screen. |
| 4.7 | As a buyer I request a refund on an order or payment, give a reason and track its status. | B | `RefundRequest`, buyer form on the order page, status. See [refund requests](refund_requests.md). |
| 4.8 | As a steward I review, approve, partly approve or decline refund requests, see the refund policy and reply to the buyer. | B | Queue at `/billing/refund_requests`, notifications, reuses `Refunds::Record`. The refund policy text is not shown yet. |
| 4.9 | As a buyer I see refund status, amount and tax on my order page. | B | Request state, approved amount and the reply show on the order page. |
| 4.10 | As a buyer I cancel an unpaid order or an offline payment claim. | P | Claim exists; buyer cancel of an awaiting payment order unconfirmed. |
| 4.11 | As a buyer I see my store credit, lots and expiry and redeem a promotion code. | B | `/billing/credit`. |
| 4.12 | As a buyer I accept changed agreements when terms change. | B | `needs_agreement` flow. |
| 4.13 | As a buyer I update my billing address and tax id for future invoices. | P | Captured at checkout; no standalone editor. |
| 4.14 | As a buyer I am notified of renewals, failures, refunds and access changes, and manage preferences. | P | Notifications exist; preference control unconfirmed. |

## Cross cutting stories

- As P12 I see public plans and prices without signing in. Plans can be public, members only or hidden.
- As P10 I place a plan card, comparison, join button, donate button, registration or my subscription block on
  any page, following the content block completeness checklist.
- As P1 I preview what a visitor sees before publishing a plan.
- As P9 I export members, shares, donations and registrations as CSV.

## Gap register

| ID | Gap | Needed by | Size |
|---|---|---|---|
| G1 | Public catalog, plan detail, comparison, buy buttons, plan visibility | all | M |
| G2 | Commerce content blocks (plan list, comparison, call to action, donate, my subscriptions) | all | M |
| G3 | Multi-line checkout, add-ons, guest checkout, return to checkout after sign in | 1, 2, 3 | L |
| G4 | Plan change with proration, add-ons, downgrade guard | 1, 3 | L |
| G5 | Provisioning entitlement (`platform_provisioning`, `hosted_platform`, suspension), subdomain picker | 0, 1 | L |
| G6 | Hosting plan page for the platform owner | 1 | S |
| G7 | Custom domain add-on, DNS verification, TLS | 1 | M |
| G8 | Per platform processors and webhooks (hosted platform sells) | 2, 3 | XL |
| G9 | Event registration with fees and member pricing | 2 | L |
| G10 | Donations (one off, recurring, open amount, receipts) | 3 | M |
| G11 | Common share ledger and board approved withdrawal | 3 | L |
| G12 | Community sold plans, seller entitlements, community billing permission | 3 | L |
| G13 | Dropped by decision (a sub-community is an ordinary community) | | |
| G14 | Free plans and $0 checkout verified, application and approval flow | 0, 3 | S |
| G15 | Separate instance fulfilment (operator task, manual first) | 1 | M |
| G16 | Price rules (member price, comps, price discounts) | 2 | M |
| G17 | Roster and ledger exports | 2, 3 | S |
| G18 | Connected accounts and fee splits for merchant of record | 3 | XL |
| G19 | Buyer billing hub and account menu links | all | S |
| G20 | Refund requests: buyer form, steward queue, policy text, notifications | all | M |
| G21 | Order filters, cross order receipts, change payment method, billing address editor, notification preferences | all | M |
| G22 | Hosted billing enablement: three agreements, per mode gates, steward status page | 2, 3 | L |
| G23 | Project and task system for BTS operators (design, then minimal implementation) | 1 | L |
| G24 | Future spec only: charitable receipt donations | 3 | S (doc) |

## Decisions (recorded 2026-11-10)

1. **Money for hosted platforms.** Each hosted platform connects its own processor account. The host can also
   act as merchant of record by default, after the hosted platform accepts the merchant onboarding agreement.
   Hosted platforms can offer local methods (cash, cheque, e-Transfer) with no processor and no merchant of
   record agreement, after accepting a hosted local billing agreement that absolves the host of liability for
   local transactions. Every hosted platform must first accept the hosted platform billing agreement before
   enabling any billing, local or remote.
2. **Tier C fulfilment.** A paid order creates a provisioning task for BTS operators. This needs an initial
   design and implementation of a project and task system (G23).
3. **Checkout.** Start with direct checkout. No standing cart in the first implementation.
4. **Common share.** Held as a member equity liability and not taxable. Withdrawal needs board approval,
   decided manually.
5. **Donations.** Donations to the co-op do not require charitable receipts. A future spec covers charitable
   tax status donations and receipts (G24).
6. **Sub-communities.** A sub-community is its own community with plans and membership, tied to the host only
   through platform scoping. No hierarchy work.

## Hosted billing enablement

Each gate is accepted through the shared agreement mechanism, recorded with who accepted and which version,
and enforced on the server as well as in the UI.

| Gate | Unlocks | Prerequisite | Notes |
|---|---|---|---|
| Hosted platform billing agreement | Any billing on that platform | none | Required first, for local and remote alike. |
| Hosted local billing agreement | Cash, cheque and e-Transfer | Billing agreement | Absolves the host of liability for local transactions. No processor or merchant of record needed. |
| Own processor connection | Remote methods through the platform's own account | Billing agreement | Credentials and webhooks per platform, test connection. |
| Merchant onboarding agreement | Host as merchant of record | Billing agreement | Host collects and pays out, takes a fee split, and is the tax registrant for those sales. Needs accounting and legal review before it is built. |

The agreement texts ship as draft placeholders and need legal review before a hosted platform can accept
them. Withdrawing or superseding an agreement pauses that platform's affected billing mode and deletes
nothing.

## Proposed stack

Every branch is cut from `feature/billing` and stacked on the previous one. Each PR carries its screenshots,
diagrams, four locales and DOM contracts.

| Step | Work | Gaps |
|---|---|---|
| D0 | Free plan hardening: specs and fixes for a $0 plan through checkout, order, entitlement and membership grant; application and approval hook. No UI. | G14 |
| D1a | Buyer billing hub: account menu entries and a `/billing` page gathering plans, renewals, orders, credit and access. No backend change. | G19 |
| D1b | Storefront: public `/plans` catalog and plan detail, plan visibility, Subscribe button, `PlanCatalogBlock` and `PlanButtonBlock`. | G1, G2 |
| D2 | Direct checkout composition: multi-line checkout, add-ons, return to checkout after sign in, guest checkout for donations. | G3 |
| D3 | Plan change with proration and guards, and the platform "Plan and usage" page. | G4, G6 |
| D3a | Hosted billing enablement, local methods first, through the shared agreement mechanism. | G22 |
| D3b | Refund requests and account polish. | G20, G21 |
| D4a | Task system: survey existing task or checklist models, design doc, minimal implementation. | G23 |
| D4 | Provisioning: entitlement kind, job, subdomain picker, community as primary, suspension, custom domain add-on; tier C creates an operator task. | G5, G7, G15 |
| D5 | Donations. | G10 |
| D6 | Shares: ledger, share line, board approved withdrawal, report. | G11 |
| D7 | Event registration with fees, member pricing and bundling with a membership. | G9, G16 |
| D8 | Hosted processors: per platform credentials and webhooks. | G8 |
| D9 | Merchant of record mode, after accounting and legal review. | G18, G22 |
| D10 | Community sold plans with seller entitlements and renewals. | G12 |
| D11 | Charitable donations spec (document only). | G24 |

D1a, D1b and D2 unblock every scenario and do not depend on how hosted platforms collect money. Provisioning
(D4) needs D1b to be reachable. Scenarios 2 and 3 need D3a first and D8 for remote methods.
