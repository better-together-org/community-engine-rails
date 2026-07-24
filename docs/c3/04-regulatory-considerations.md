# C3 Tree Seeds — Regulatory Considerations

This document is intended for BTS leadership, legal advisors, and regulators. It explains the nature of C3 Tree Seeds in relation to financial regulations, anti-money-laundering frameworks, data residency requirements, and community governance.

**Plain language summary:** Tree Seeds are a community timebank token. They are not money, not a security, and not an investment instrument. They are earned by contributing to the community and spent by exchanging time and skills with other members. The closest legal analogy is a mutual aid credit in a time-banking cooperative.

---

## Nature of C3: Not a Security, Not Money

Tree Seeds do not meet the legal definitions of a security or a monetary instrument under the frameworks most commonly applicable to community platforms:

### Not a Security

The Howey Test (US) and equivalent tests in Canadian and EU jurisdictions define a security as: an investment of money in a common enterprise with an expectation of profit from the efforts of others.

Tree Seeds fail all three prongs:
- **No investment of money**: Tree Seeds are earned through labour and contribution, not purchased.
- **No common enterprise for profit**: The BTS network is a non-profit co-operative. There is no profit pool.
- **No expectation of profit**: Tree Seeds cannot be converted to money and do not appreciate in value.

### Not Money

Tree Seeds are not a currency under definitions used by the Bank for International Settlements, FINTRAC (Canada), FinCEN (US), or the EU's Payment Services Directive:

- **Not a medium of exchange for goods and services outside the network**: Tree Seeds can only be used within the BTS community platform for member-to-member time exchanges.
- **Not fiat-backed**: There is no reserve of money backing Tree Seeds.
- **Not convertible**: There is no mechanism to convert Tree Seeds to any fiat currency or to any other cryptocurrency.
- **Not transferable to third parties**: Tree Seeds can only be exchanged between members of the same community platform (or, with bilateral opt-in, between platforms in the BTS network).

### Community Currency Doctrine

Tree Seeds are most accurately classified as a **community currency** or **mutual credit instrument** — the same legal category as:
- Time banking credits (e.g., TimeBanks USA; Community Exchange System)
- Local exchange trading systems (LETS)
- Co-operative labour credits

These systems have a long legal history in many jurisdictions and are generally not regulated as money or securities precisely because they lack convertibility to fiat and are bounded to a specific community.

---

## Anti-Money Laundering Posture

### Why AML Does Not Apply

AML regulations target the movement of money through financial systems to conceal criminal proceeds. Tree Seeds are:
- Not convertible to money (no off-ramp)
- Not usable outside the BTS community network
- Not transferable between unrelated third parties

The absence of any fiat-in or fiat-out pathway means Tree Seeds do not fall within the scope of FINTRAC's MSB regulations, FinCEN's money services business rules, or the EU's AMLD.

### What We Do Anyway (Voluntary Audit Trail)

Even where regulations do not require it, BTS maintains a complete audit trail:

- Every C3 contribution event creates an immutable **C3::Token** record with: contributor identity, amount, contribution type, source evidence, timestamps.
- Every locked amount creates a **C3::BalanceLock** record with: payer, amount, expiry, agreement reference, source platform.
- Every exchange creates a **Joatu::Settlement** record with: payer, recipient, amount, outcome.
- Every cross-platform federation event creates a **C3::TokenSeed** record with: sending platform, receiving platform, earner DID, amount, payload hash.

This means that if a question ever arises about a C3 transaction — from any party — it can be fully reconstructed from immutable records.

### Governance Separation

BTS uses a one-member-one-vote system for democratic decisions. C3 balance does not affect voting weight. This is a hard architectural constraint. The separation is documented, enforced in code, and does not require configuration. Accumulating Tree Seeds grants no special influence over community decisions.

---

## Data Residency

Tree Seeds balances and transaction records are stored in Community Engine's PostgreSQL database, which resides on BTS-operated servers. Key properties:

- **Balances are per-platform**: A member's balance on Platform A is stored on Platform A's database. There is no central aggregating database.
- **Cross-platform exchange**: When Platform A sends Tree Seeds to Platform B, a **C3::TokenSeed** record is created on Platform B. No personal data from Platform A (other than the earner's borgberry DID, which is encrypted at rest) travels to Platform B.
- **borgberry DID**: The decentralised identifier used to link a member across platforms is stored with AR::Encryption (at-rest encryption). It is not readable from the database without the application's encryption key.
- **No cross-border data movement required**: All BTS servers are currently located in Canada. Cross-platform exchange between platforms on the same server cluster does not involve data crossing jurisdictions.

---

## Cross-Platform Exchange Controls

Cross-platform Tree Seeds exchange has explicit controls at every layer:

| Control | What it requires |
|---|---|
| Platform-level opt-in | Both platform administrators must set `allow_c3_exchange: true` on their `PlatformConnection` |
| Member-level DID | An earner must have a borgberry DID registered on the sending platform |
| Active connection | The `PlatformConnection` must be in `active` status |
| Exchange rate | Platform administrators set the rate explicitly (default 1:1) |
| Rate audit | The exchange rate applied to each transaction is stored in the minted C3::Token metadata |

Neither platform can unilaterally initiate exchange. If either platform revokes consent (sets `allow_c3_exchange: false` or deactivates the connection), no further exchange occurs.

---

## Audit Completeness

The following records are created for every C3 event:

| Event | Record(s) created |
|---|---|
| Contribution earned | `C3::Token` (contribution_type, earner, c3_millitokens, source_ref, source_system, timestamps) |
| Balance update | `C3::Balance` (available, locked, lifetime — running totals, updated atomically) |
| Agreement accepted (C3-priced) | `C3::BalanceLock` (lock_ref, millitokens, expires_at, agreement_ref, source_platform) |
| Agreement fulfilled | `Joatu::Settlement` (completed), new `C3::Token` (joatu_exchange type), `C3::BalanceLock` settled |
| Agreement cancelled | `Joatu::Settlement` (cancelled), `C3::BalanceLock` released, C3 returned |
| Lock expired | `C3::BalanceLock` (expired), C3 returned — logged by `ExpireBalanceLocksJob` |
| Cross-platform credit | `C3::TokenSeed` (full payload), `C3::Token` (federated: true), `C3::Balance` updated |
| Fleet registration | `FleetNode` (node_id, IPs, Noise public key) |

All records are append-only or status-transition-only. No C3 event is destructively deleted.

---

## Recommended Governance Steps Before Live Cross-Platform Exchange

Before the C3 cross-platform exchange feature is enabled in production between real community members, BTS should take the following governance steps:

### 1. BCC Formal Resolution

The **Borgberry Community Collective (BCC)** should pass a formal resolution that:
- Confirms Tree Seeds are a non-monetary community contribution token
- Confirms the one-member-one-vote principle is not affected by C3 balance
- Confirms the bilateral opt-in requirement for cross-platform exchange
- Records the date and signatories

This resolution does not need to be filed with any regulator — it is an internal governance record that establishes clear intent.

### 2. Legal Review (Recommended, Not Blocking)

Before enabling cross-platform exchange at significant scale, a brief legal review against the applicable community currency regulations in the primary jurisdictions of BTS members (primarily Canada, with consideration of EU and US members) is advisable. The cost of this review is low; the clarity it provides is significant.

### 3. Monitoring Triggers

The following scenarios would require re-assessment of regulatory status. They are **not currently applicable** but should be monitored:

| Trigger | Why it matters |
|---|---|
| Tree Seeds become exchangeable for goods or services from vendors outside the BTS network | Expands the scope of the "currency" beyond the community |
| A secondary market emerges | Would indicate speculative use and possible security classification |
| A member offers fiat-for-Tree-Seeds exchanges | Would create a fiat on/off-ramp and trigger MSB considerations |
| Tree Seeds are used to pay for professional services from non-members | Blurs the community-currency boundary |

If any of these triggers occur, BTS should immediately pause cross-platform exchange and seek legal advice.

---

## Summary Table

| Question | Answer |
|---|---|
| Is C3 a security? | No — no investment of money, no common enterprise, no expectation of profit |
| Is C3 money or currency? | No — not convertible to fiat, not usable outside BTS network |
| Does AML apply? | No — no fiat on/off-ramp; voluntary audit trail maintained regardless |
| Is data stored in Canada? | Yes — all BTS servers currently Canadian-hosted |
| Does C3 affect governance votes? | Never — one-member-one-vote is a hard architectural constraint |
| Can cross-platform exchange be disabled? | Yes — bilateral opt-in; either platform can withdraw consent |
| Is there a complete audit trail? | Yes — every C3 event produces an immutable record |
