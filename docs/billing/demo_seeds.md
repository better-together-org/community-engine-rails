# Billing demo seeds

A small demo catalog for trying billing end to end, planted with the Seed Packet Protocol 2.0 like the navigation and RBAC packets. Every name starts with `[Demo]`, so it is easy to recognise and remove.

## What the packet plants

Packet: `config/seeds/better_together/billing_demo`, mode `add_only` (a rerun creates what is missing and never overwrites a steward's edits).

| Plan | Price | Pay by | Includes |
|---|---|---|---|
| `demo-free` | free | n/a | nothing |
| `demo-supporter-monthly` | 10.00 CAD / month | cash, cheque, e-transfer | 5 GiB media storage |
| `demo-supporter-annual` | 100.00 CAD / year | cash, cheque, e-transfer | 5 GiB media storage |
| `demo-cheque-only` | 25.00 CAD / month | cheque only | nothing |
| `demo-extra-storage` | 3.00 CAD once | cash, cheque, e-transfer | add-on, offered with both supporter plans |

Plans have no vendor processor, so they settle through the offline methods. Add-ons cannot hold grants (the model refuses), so the extra-storage add-on is a plain extra.

## Planting

```bash
bin/dummy rake better_together:seeds:plan  PACKET=config/seeds/better_together/billing_demo PLATFORM=<platform identifier>
bin/dummy rake better_together:seeds:plant PACKET=config/seeds/better_together/billing_demo PLATFORM=<platform identifier> APPLY=1
```

Run `plan` first (it writes nothing), then `plant`. A second `plant` reports every record `unchanged`.

## What is not in the packet, and why

These have their own gates, so a steward or a companion step does them, not a packet:

- **Payment methods.** Enabling one needs an acknowledgement by a named person, so it cannot be seeded.
- **Purchase agreements.** `Billing::PurchaseAgreementSeeds` plants them as drafts; a steward reviews and activates them. Until then checkout fails closed.
- **Tax.** The Canadian tax packet (`billing/billing_tax_canada.yml`) plants categories, zones and rates, and needs geography data first.
- **Promotion codes, store credit, orders and subscriptions.** They go through services (digested codes, ledger entries, payment state), not records.
