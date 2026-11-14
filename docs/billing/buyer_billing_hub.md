# Buyer billing page

The buyer billing page is one place where a signed-in person sees what they have bought on a platform and
follows a link to the full page for each part. It reads only; every action (cancel, pay, accept agreements) happens on
the page it links to. See [orders_and_payments.md](orders_and_payments.md),
[subscriptions_and_renewals.md](subscriptions_and_renewals.md), [store_credit.md](store_credit.md) and
[entitlements_and_allowances.md](entitlements_and_allowances.md) for those pages.

## Who can reach it

- Route: `/:locale/billing` (`billing_hub_path`), served by `Billing::HubsController#show`.
- Actor: any signed-in person. It is **their own** billing, not a steward screen, so it needs no
  `manage_billing` permission; the policy question is the same one the person's order list asks (`OrderPolicy#index?`).
- Gate: billing must be on for the platform (`BetterTogether::Billing.enabled?`). When it is off, the page answers
  **404 before sign-in is asked for**, so a platform that has not set billing up does not reveal that the page exists.
  A signed-out visitor to a billing-enabled platform is sent to sign in.
- Entry point: a **Billing** item in the account menu (the user navigation dropdown). It is shown only while billing
  is enabled for the host platform.

## What it shows

Each area is a labelled section with a heading and a text link to its full page.

| Area | Content | Full page |
|---|---|---|
| Plans | Up to five of the person's own active, trialing or past-due locally run subscriptions: plan name, renewal date, price. | subscriptions |
| Orders | Their five newest orders as buyer: number, status badge, total. | orders (paged) |
| Store credit | The usable balance per currency, only where positive. | credit |
| Access | A count of the live entitlements the person has through their plans. | access |

Every section has an empty state, so a new member sees a sentence rather than a blank card.

## Data scoping

- Everything is loaded through `billing_owner` (the current platform), never with a bare class-level read, so another
  platform's records cannot appear.
- Plans are limited to subscriptions whose customer is this person; orders to those bought by this person; credit to
  accounts held by this person. Another person's records are never loaded, whatever the request.
- The access count comes from `Billing::Entitlements::ForPerson`, the same lookup the person's access page uses.

## Flow

1. The person opens **Billing** in the account menu.
2. The controller checks billing is on, that they are signed in and authorized, then loads the four summaries.
3. The page renders four sections. Following a section's link goes to that area's own page (the orders link opens the
   paged order list).
