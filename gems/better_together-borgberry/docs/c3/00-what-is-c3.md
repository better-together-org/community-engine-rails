# What are Tree Seeds? A Plain-Language Guide to C3

Tree Seeds are a way for community members to recognise and reward each other's contributions. When someone donates their computer's processing power overnight to help the community, spends an afternoon teaching a skill, reviews someone's code, or moderates a forum — they earn Tree Seeds. Those seeds can later be exchanged with other community members in return for help, time, or skills.

Think of it like a community timebank. If you give an hour of your time today, you earn credits you can use to receive an hour of someone else's time later. The name "Tree Seeds" comes from the NL pronunciation of the three-letter acronym C3 — and from the idea that small contributions, like seeds, grow into something larger together.

Tree Seeds are not money. They cannot be converted to dollars, euros, or any other currency. They have no monetary value, are not traded on any market, and are not an investment. They are a community coordination tool — a way to make visible the labour and care that holds communities together.

---

## Who Earns Tree Seeds

Anyone whose device or time contributes to the network can earn Tree Seeds. Examples:

| Contribution | How it earns |
|---|---|
| Computer running jobs overnight | Automatically via borgberry (the fleet management system) |
| GPU compute for ML/transcription | Automatically via borgberry |
| Volunteer time | Logged and approved by a community steward |
| Code review | Logged when a pull request review is submitted |
| Documentation writing | Logged when a documentation PR is merged |
| Community moderation | Logged when moderation actions are completed in CE |
| Embedding generation | Automatically when vectors are created for the knowledge base |

Earning is automatic where possible. For volunteer time and code review, a community steward approves the contribution and it is logged.

---

## Who Can Spend Tree Seeds

Any community member can use Tree Seeds to enter into a peer exchange with another member through the Joatu system (Joatu is the exchange layer built into Community Engine). Here is how it works:

1. A member posts an **offer** ("I can help you set up your website — 3 Tree Seeds per hour") or a **request** ("I need help moving furniture — happy to pay 10 Tree Seeds").
2. Another member responds.
3. When both parties agree, the payer's Tree Seeds are **reserved** (locked) for that exchange.
4. When the service is delivered, the Tree Seeds are transferred to the provider.
5. If the exchange is cancelled, the Tree Seeds are returned to the payer automatically.

There is no intermediary. No platform takes a cut. The exchange is directly between two people.

---

## What Tree Seeds Are NOT

- **Not money.** Tree Seeds cannot be converted to any currency.
- **Not an investment.** Tree Seeds do not appreciate in value. They are contribution credits, not financial instruments.
- **Not tradeable on markets.** There is no exchange, no secondary market, and no trading mechanism.
- **Not securities.** They do not represent ownership, equity, or a claim on future earnings.
- **Not inflationary.** There is no central authority issuing Tree Seeds speculatively. Every Tree Seed is backed by a recorded contribution.
- **Not a governance instrument.** Community decisions use a one-member-one-vote system. Holding more Tree Seeds does not give you more say.

---

## Privacy: Who Can See Your Balance

Your Tree Seeds balance is private by default. You can see your own balance on your profile page. Community administrators can see balances for platform governance purposes.

**Cross-platform balances** (Tree Seeds earned on one platform and held on another) are hidden by default behind a privacy toggle on your profile. You must actively choose to reveal this information. This is intentional: the fact that you participate in multiple BTS communities is your business, not the platform's.

The underlying technical systems are designed to minimise what operators can learn about communication patterns, even if they have access to the servers. Relay logs are anonymised before being written to disk. Direct message payloads are end-to-end encrypted.

---

## Cross-Platform Exchange

The BTS network includes multiple community platforms. Tree Seeds earned on one platform can, with the explicit consent of both platforms and both members, be recognised and held on another platform.

This cross-platform exchange requires:
1. **Both platforms must opt in** — the platform administrators of both platforms must enable C3 exchange on their connection.
2. **The earner must be enrolled** on the receiving platform (or the credit is held pending their joining).
3. **An exchange rate** is set by the platform connection administrators. The default is 1:1.

No cross-platform movement of Tree Seeds happens without these conditions being met.

---

## Governance

The BTS co-operative model is one-member-one-vote. C3 balances have no effect on voting weight. This is a firm architectural decision: community economic participation (Tree Seeds) is deliberately separated from democratic participation (voting).

Tree Seeds are governed by the **Borgberry Community Collective (BCC)** — the group of community members who steward the borgberry network and the C3 system. Before live cross-platform exchange is enabled between real community members, the BCC should pass a formal resolution confirming the non-monetary nature of C3 and the governance separation. See [04-regulatory-considerations.md](./04-regulatory-considerations.md) for more detail.

---

## Technical Summary

For readers who want the technical picture in brief:

- Tree Seeds are stored as **millitokens** (integers) in the database for precision arithmetic. 1 Tree Seed = 1,000 millitokens. You never see millitokens in the interface.
- Every contribution is recorded as a **C3::Token** — an immutable audit record with the contributor, the amount, the type, and the source evidence.
- Balances are tracked in **C3::Balance** — a running total per person.
- Locked amounts (reserved for pending exchanges) are tracked in **C3::BalanceLock** — an audit record with a 24-hour expiry.
- The data model, flows, and security architecture are documented in detail in the companion documents:
  - [01-data-model.md](./01-data-model.md) — all tables, fields, and state machines
  - [02-flows.md](./02-flows.md) — how transactions move through the system
  - [03-network-and-security.md](./03-network-and-security.md) — encryption, network topology, access control
  - [04-regulatory-considerations.md](./04-regulatory-considerations.md) — regulatory posture and governance
