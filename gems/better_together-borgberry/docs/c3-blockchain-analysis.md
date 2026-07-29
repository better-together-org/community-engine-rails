# C3 + Blockchain: Suitability Analysis

> **Question**: Would a blockchain ledger be appropriate for C3 contribution tracking,
> for the goals of auditing, transparency, and immutable ledger entries?
>
> **Short answer**: Not as the primary operational ledger. The properties you want
> are achievable more simply. However, cryptographic verifiability (a close cousin)
> is both appropriate and already partially designed into the system.

---

## 1. How Blockchains Work

A blockchain is a data structure where each record (block) contains:
1. A set of transactions
2. A cryptographic hash of the *previous* block
3. A timestamp
4. A nonce (in proof-of-work systems)

```mermaid
graph LR
    G["Genesis Block\nhash: 0000abc\nprev: 0000000\ntxns: []"]
    B1["Block 1\nhash: 1234def\nprev: 0000abc\ntxns: [Alice→Bob: 5]"]
    B2["Block 2\nhash: 5678ghi\nprev: 1234def\ntxns: [Bob→Carol: 3]"]
    B3["Block 3\nhash: 9012jkl\nprev: 5678ghi\ntxns: [Carol→Alice: 1]"]

    G --> B1 --> B2 --> B3
```

**Why this gives immutability**: changing Block 1's transactions changes its hash, which breaks Block 2's `prev` pointer, which changes Block 2's hash, breaking Block 3, and so on. Every subsequent block must be recomputed. In a network with many participants, you'd also need to convince >50% of the network to accept your altered chain — the 51% attack threshold.

**The three properties you asked about:**

| Property | How blockchain achieves it | What you actually need |
|----------|---------------------------|----------------------|
| **Immutability** | Hash-chaining makes retroactive edits detectable | Append-only records + cryptographic signing |
| **Auditability** | Full transaction history always present on every node | Event log with no deletes |
| **Transparency** | All participants can read the full chain | Open API + open-source code |

The key insight: **blockchain bundles these three properties together with decentralisation and trustlessness**. If you need the three properties but *not* decentralisation/trustlessness, you don't need a blockchain.

---

## 2. Types of Blockchains (Spectrum)

```mermaid
graph LR
    subgraph "Fully Decentralised"
        BTC["Bitcoin / Ethereum\n• Anyone can participate\n• No admin\n• Gas fees per transaction\n• 10s–minutes to confirm\n• All data public forever"]
    end
    subgraph "Public Permissioned"
        POL["Polygon / Solana\n• Validators are known entities\n• Still public ledger\n• Faster, cheaper\n• Data still public"]
    end
    subgraph "Private Permissioned"
        HYP["Hyperledger Fabric / Corda\n• Consortium controls validators\n• Transactions can be private\n• Fast (~1s)\n• You run the infrastructure"]
    end
    subgraph "Single-node"
        PG["Append-only PostgreSQL\n• One trusted operator\n• Cryptographic signing optional\n• Millisecond writes\n• Full SQL query power"]
    end

    BTC -->|"more trust required →"| POL -->|| HYP -->|| PG
    PG -->|"← more decentralisation"| HYP -->|| POL -->|| BTC
```

As you move right, you gain **operational simplicity, speed, and query power**. As you move left, you gain **trustlessness** (ability to transact with parties you don't trust without a central authority).

---

## 3. The Oracle Problem — Why Blockchain Doesn't Solve the Core Trust Question

This is the critical issue for C3 specifically.

```mermaid
sequenceDiagram
    participant B as Borgberry Node (bts-7)
    participant OR as Oracle Problem
    participant BC as Blockchain
    participant V as Any Verifier

    B->>OR: "I ran a 12-GPU-hour inference job"
    Note over OR: WHO VERIFIES THIS CLAIM?
    OR->>BC: smart contract: mint(earner, 1200 C3)
    BC->>BC: record is now immutable on chain

    V->>BC: verify: did this job really run?
    BC-->>V: "yes — the chain says so"
    Note over V: But the chain only knows what<br/>the oracle (borgberry) told it.<br/>If borgberry lied, the chain<br/>faithfully records the lie immutably.
```

**The blockchain makes the ledger entries immutable. It cannot make the input data true.**

For C3 specifically:
- Borgberry nodes report job completions to CE
- CE mints C3 tokens based on those reports
- If a borgberry node reports a fake job, a blockchain mints fake C3 just as faithfully as PostgreSQL does

The trust question is: **"Did this compute work actually happen?"** — and that question lives upstream of whatever ledger you use. Blockchain solves "can the ledger be tampered with after the fact?" It does not solve "was the input to the ledger honest?"

This oracle problem is why existing crypto platforms like Chainlink exist — entire companies are built around the problem of getting reliable real-world data onto a blockchain.

---

## 4. What the C3 Design Already Gets Right

The current architecture actually addresses all three goals through simpler means:

### Immutability via append-only design

`C3::Token` is already designed as an immutable event log:
- No `update` or `delete` in the controller or model
- The status FSM (`pending → confirmed → settled`) only moves forward
- `lifetime_earned_millitokens` on `C3::Balance` is monotonically increasing — it's never decremented

This can be enforced at the database level with a trigger:

```sql
CREATE RULE c3_tokens_no_update AS ON UPDATE TO better_together_c3_tokens
  DO INSTEAD NOTHING;
CREATE RULE c3_tokens_no_delete AS ON DELETE TO better_together_c3_tokens
  DO INSTEAD NOTHING;
```

**This gives you blockchain-grade immutability without a blockchain.**

### Auditability via the event log

Every C3 earning event is a separate `C3::Token` row with:
- `source_ref` — the job ID or event that triggered it
- `source_system` — which system emitted it (`borgberry`, `ce_governance`, `ce_metrics`)
- `emitted_at`, `confirmed_at` — full timestamp trail
- `contribution_type`, `units`, `duration_s`, `metadata` — full provenance

### Transparency via open source + open API

The CE codebase is open source. The `GET /api/v1/c3/contributions` and `GET /api/v1/c3/balance` endpoints expose the full record. Anyone who can read the API can audit any holder's balance against their token history.

---

## 5. What Blockchain Would Actually Add (and at What Cost)

```mermaid
graph TD
    subgraph "What you get with blockchain"
        A["Trustless cross-org exchange\n(orgs that don't trust each other\ncan share a ledger)"]
        B["Censorship resistance\n(BTS cannot erase a token\neven if it wanted to)"]
        C["Public proof of contribution\n(anyone can verify without\nasking BTS)"]
        D["Smart contract automation\n(settlement triggers without\nCE server involvement)"]
    end

    subgraph "What you pay"
        E["Gas fees per transaction\n(Ethereum: $0.01–$50+ each)"]
        F["Confirmation latency\n(12s on Ethereum,\neven 'fast' chains: 1–5s)"]
        G["No SQL queries\n(can't do SELECT * WHERE\non a blockchain)"]
        H["Operational complexity\n(node infrastructure,\nkey management, upgrades)"]
        I["Data permanence\n(you can never delete\npersonal data — GDPR problem)"]
        J["Public exposure\n(all contribution history\npublic by default)"]
    end

    A & B & C & D -->|"worth it if you need trustlessness\nacross untrusted organisations"| YES
    E & F & G & H & I & J -->|"steep price to pay\nfor a single-org deployment"| NO
```

**The GDPR problem is particularly sharp**: a person's right to erasure (GDPR Article 17) is structurally incompatible with a public immutable blockchain. A person can demand their contribution history be deleted — you can't do that on Ethereum. A private permissioned chain could be wiped, but then you're back to trusting whoever controls the validators.

---

## 6. The Better Alternative — Cryptographic Verifiability

The borgberry system already has the pieces for a much more appropriate solution: **W3C Verifiable Credentials** using the DID infrastructure already in the design.

```mermaid
graph TD
    subgraph "Already in the design"
        P["Person.borgberry_did\n'did:key:z6Mk...' — W3C DID\nderived from operator GPG key"]
        N["Fleet::Node\nnoise_public_key on PlatformConnection"]
        T["C3::Token\nsource_ref, emitted_at, metadata"]
    end

    subgraph "Proposed extension"
        VC["Verifiable Credential (W3C VC)\n{\n  '@context': 'https://www.w3.org/2018/credentials/v1',\n  'type': ['VerifiableCredential', 'C3ContributionCredential'],\n  'issuer': 'did:key:z6Mk...' (borgberry node DID),\n  'credentialSubject': {\n    'id': person.borgberry_did,\n    'c3Amount': 18.75,\n    'contributionType': 'compute_gpu',\n    'sourceRef': 'job:abc123'\n  },\n  'proof': { 'type': 'Ed25519Signature2020', ... }\n}"]
    end

    P --> VC
    N --> VC
    T --> VC

    V["Any verifier anywhere\ncan check the signature\nwithout asking BTS"]
    VC --> V
```

**How this works:**

1. When borgberry completes a job, it signs a Verifiable Credential with the node's private key (already derived from the GPG key that generates `borgberry_did`)
2. CE stores both the `C3::Token` row AND the signed VC JSON in `metadata`
3. Anyone can verify the credential signature using the node's public DID — without trusting CE's database
4. The credential is portable — the person can take it to another platform and prove their contribution history
5. No blockchain required, no gas fees, GDPR-compliant (you can revoke a VC)

This is what the `borgberry_did` column is pointing toward. It's not blockchain — it's the same cryptographic verifiability without the overhead.

---

## 7. When Blockchain Would Be the Right Answer

There is one realistic future scenario where a blockchain becomes appropriate: **multi-organisation C3 exchange**.

```mermaid
graph TD
    subgraph "BTS — Community Engine instance A"
        CE_A["CE instance A\nPostgreSQL C3 ledger"]
        P_A["Person Alice\nborgberry_did: did:key:zAlice"]
    end

    subgraph "Partner Co-op — Community Engine instance B"
        CE_B["CE instance B\nPostgreSQL C3 ledger"]
        P_B["Person Bob\nborgberry_did: did:key:zBob"]
    end

    subgraph "Shared Permissioned Chain (Hyperledger / EVM sidechain)"
        SC["Cross-org C3 smart contract\n• Alice sends 5 C3 to Bob\n• Both orgs validate the transfer\n• Neither org controls the ledger\n• Settlement is trustless"]
    end

    CE_A -->|"Alice bridges 5 C3 to chain"| SC
    SC -->|"Bob redeems on his CE instance"| CE_B

    note["This is the only scenario where you need\nblockchain — when two organisations that\ndon't fully trust each other want to exchange\nvalue without a central arbitrator"]
    SC --> note
```

For a single-organisation deployment (BTS running its own borgberry + CE), this scenario doesn't apply. If the C3 network grows to include independent partner orgs that want to exchange contributions peer-to-peer, a **private permissioned chain** (Hyperledger Fabric, or a simple EVM chain using Tendermint consensus) becomes genuinely valuable.

---

## 8. Recommendation

```mermaid
graph TD
    Q1{"Do you need trustless exchange\nbetween organisations that\ndon't trust each other?"}
    Q2{"Do you need public proof of\ncontributions verifiable\nwithout asking BTS?"}
    Q3{"Do you need immutable,\naudit-ready records?"}

    A_BC["Permissioned blockchain\n(Hyperledger Fabric or EVM sidechain)\nfor cross-org bridge only"]
    A_VC["W3C Verifiable Credentials\nsigned by borgberry DID\nstored in C3::Token.metadata"]
    A_PG["Append-only PostgreSQL\n+ DB-level no-update/delete triggers\n+ Merkle root snapshots published\n  to public channel (GitHub/Nostr)"]

    Q1 -->|Yes| A_BC
    Q1 -->|No| Q2
    Q2 -->|Yes| A_VC
    Q2 -->|No| Q3
    Q3 -->|Yes| A_PG

    style A_BC fill:#fef9c3,stroke:#ca8a04
    style A_VC fill:#dcfce7,stroke:#22c55e
    style A_PG fill:#dbeafe,stroke:#3b82f6
```

**For the current BTS deployment:**

| Goal | Recommended approach | Why |
|------|---------------------|-----|
| Immutable records | Append-only `C3::Token` + DB trigger | Same guarantees, millisecond writes, full SQL |
| Auditability | Event log with `source_ref`, timestamps, `metadata` | Already implemented |
| Transparency | Open API + open-source CE code | Already there |
| Cryptographic proof | W3C VCs signed by borgberry DID | Uses infrastructure already designed in |
| Cross-org exchange | Permissioned EVM sidechain | Only if/when multi-org C3 exchange is needed |

**What not to do:** put operational C3 ledger entries on a public blockchain. The gas costs, confirmation latency, GDPR incompatibility, and oracle trust problem make it strictly worse than what the current design already achieves.

---

## 9. Merkle Snapshot — Lowest-Cost Public Auditability

If the goal is "anyone can verify the C3 ledger hasn't been tampered with" without full blockchain infrastructure, a **periodic Merkle snapshot** achieves it at near-zero cost:

```
Every Sunday at midnight:
1. SELECT id, earner_id, c3_millitokens, source_ref, emitted_at
   FROM better_together_c3_tokens ORDER BY emitted_at
2. Compute SHA-256 Merkle root of all rows
3. Publish root to: GitHub commit, Nostr note, public RSS, or even a tweet
4. Anyone can download the full token table and verify their local Merkle root matches
```

This gives **public, independently verifiable proof** that the ledger matches the published root — at the cost of one cron job and a few bytes published weekly. No blockchain, no gas, no infrastructure.

---

## Summary

Blockchain is a solution to a specific problem: **enabling trustless value exchange between mutually distrusting parties**. That's not the current problem.

The current problem is: **audit-ready, tamper-evident contribution records within a trusted community infrastructure**. PostgreSQL append-only tables with cryptographic signatures from borgberry DIDs solve this completely, at a fraction of the complexity and cost, while remaining GDPR-compliant and fully queryable.

The W3C DID infrastructure (`borgberry_did` on `Person`, `noise_public_key` on `PlatformConnection`) is the right cryptographic foundation for portable contribution credentials — it's the same verifiability as blockchain without the consensus layer overhead. A blockchain bridge becomes the right answer only if and when CE instances in multiple independent organisations want to exchange C3 cross-org without trusting a common database operator.
