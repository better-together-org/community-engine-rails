# C3 Federation — Transaction Flows

This document shows exactly how Tree Seeds move through the system for every scenario. Each flow has a plain-language summary, a sequence diagram, and a table of the records created or modified.

---

## Flow 1: Local C3 Earning

**Plain language:** When a borgberry node completes a job (compute, transcription, embedding), borgberry automatically records the contribution and credits the earner's Tree Seeds balance on their home platform. No human action is required.

```mermaid
sequenceDiagram
    participant Node as borgberry Node
    participant Emitter as borgberry_c3_emitter
    participant CE as CE API
    participant Token as C3::Token
    participant Balance as C3::Balance

    Node->>Emitter: Job complete\n(job_type, node_id, duration_s, units)
    Emitter->>CE: POST /api/v1/c3/contributions\n{Authorization: Bearer borgberry_token\n contribution_type, c3_amount,\n source_ref: job_id, source_system: borgberry}
    CE->>CE: Look up earner by borgberry_did\nLook up exchange rate for contribution_type
    CE->>Token: create!(earner, contribution_type,\nc3_millitokens, source_ref, status: confirmed)
    CE->>Balance: credit!(c3_amount)\navailable_millitokens += amount\nlifetime_earned_millitokens += amount
    CE-->>Emitter: 201 {token_id, c3_millitokens}
    Note over Node: If CE unreachable:\nqueued to logs/c3/pending-emissions.jsonl\nretried on next connection
```

**Records created/modified:**

| Record | Field changes |
|---|---|
| `C3::Token` (new) | earner, contribution_type, c3_millitokens, source_ref (encrypted), confirmed_at |
| `C3::Balance` (updated) | available_millitokens +=, lifetime_earned_millitokens += |

---

## Flow 2: Cross-Platform Token Seed

**Plain language:** When Tree Seeds earned on one platform need to be recognised on another platform (because the earner participates in both), a borgberry operator sends a "token seed" — a signed credit request — to the receiving platform. If the earner is enrolled there, their balance is credited immediately. If not, the credit is held and applied when they join.

```mermaid
sequenceDiagram
    actor Operator as borgberry Operator
    participant CLI as borgberry CLI
    participant INEM as INEM Router (optional)
    participant PeerCE as Peer CE Platform
    participant DB as Peer CE Database

    Note over Operator,DB: PlatformConnection must have allow_c3_exchange=true on both sides

    Operator->>CLI: borgberry seed c3-settle\n--earner-did did:key:z6Mk...\n--c3-amount 5.0\n--contribution-type compute_cpu\n--source-ref job:abc-123

    CLI->>CLI: checkNetworkSafety(ce_base_url)\nWarn + log incident if public internet

    alt INEM route available
        CLI->>INEM: NoiseEncrypt(payload, peer_public_key)
        INEM->>PeerCE: POST /inem/transit {NoiseCiphertext}
        PeerCE->>PeerCE: Decrypt + route to HandleINEMC3TokenSeed
    else Direct HTTPS (Headscale or LAN)
        CLI->>PeerCE: POST /federation/c3/token_seeds\n{Authorization: Bearer scope:c3.exchange}
    end

    PeerCE->>PeerCE: Authenticate + check allow_c3_exchange?
    PeerCE->>DB: Find or create C3::TokenSeed\n(identifier = SHA256(source_ref))\nRescue RecordNotUnique → 409
    PeerCE->>DB: seed.apply_to_recipient_balance!\nFind earner by borgberry_did\nApply exchange rate from PlatformConnection\nMint C3::Token (federated: true)\nCredit C3::Balance (origin_platform set)

    alt Earner found
        PeerCE-->>CLI: 201 {status: ok, applied: true}
    else Earner not yet enrolled
        PeerCE-->>CLI: 202 {status: pending, reason: earner_did_not_found_locally}
    end
```

**Records created/modified:**

| Record | Field changes |
|---|---|
| `C3::TokenSeed` (new, on peer platform) | type, identifier (hash), payload (encrypted), earner_did, c3_millitokens |
| `C3::Token` (new, on peer platform) | earner, federated: true, origin_platform, c3_millitokens (rate-adjusted), source_ref (hash) |
| `C3::Balance` (new or updated, on peer platform) | origin_platform set, available_millitokens +=, lifetime_earned_millitokens += |

---

## Flow 3: Agreement Lock (Accepting a C3-Priced Offer)

**Plain language:** When someone accepts an offer that has a Tree Seeds price, the right amount of Tree Seeds is immediately set aside (locked) from their balance. They can't spend those seeds elsewhere, but they haven't paid yet — the seeds are held in reserve until the service is delivered.

```mermaid
sequenceDiagram
    actor Payer
    participant CE as CE
    participant Balance as C3::Balance (Payer)
    participant Lock as C3::BalanceLock
    participant Settlement as Joatu::Settlement

    Payer->>CE: accept! agreement\n(c3_price_millitokens > 0)

    CE->>Balance: lock!(c3_amount,\nagreement_ref: agreement.id)
    Balance->>Balance: Check available ≥ amount
    alt Insufficient balance
        Balance-->>CE: raise InsufficientBalance
        CE-->>Payer: Flash: "You need X more Tree Seeds\nYour balance: Y Tree Seeds"
    end
    Balance->>Balance: available_millitokens -= amount\nlocked_millitokens += amount
    Balance->>Lock: create!(millitokens, expires_at: now+24h,\nagreement_ref, source_platform)
    Lock-->>Balance: lock_ref (UUID)

    CE->>Settlement: create!(pending, payer, recipient,\nc3_millitokens, lock_ref)
    CE-->>Payer: "X Tree Seeds reserved for this agreement.\nThey'll be returned if the agreement is cancelled."
```

**Records created/modified:**

| Record | Field changes |
|---|---|
| `C3::Balance` (payer, updated) | available_millitokens -=, locked_millitokens += |
| `C3::BalanceLock` (new) | balance_id, lock_ref, millitokens, expires_at, status: pending |
| `Joatu::Settlement` (new) | agreement_id, payer, recipient, c3_millitokens, lock_ref, status: pending |
| `Joatu::Agreement` (updated) | status: accepted |

---

## Flow 4: Settlement Complete (Agreement Fulfilled)

**Plain language:** When both parties confirm the service has been delivered, the reserved Tree Seeds are transferred to the provider. An immutable record of the exchange is minted. Both parties receive a notification.

```mermaid
sequenceDiagram
    actor Provider
    participant CE as CE
    participant Settlement as Joatu::Settlement
    participant PayerBal as C3::Balance (Payer)
    participant RecipBal as C3::Balance (Recipient)
    participant Lock as C3::BalanceLock
    participant Token as C3::Token

    Provider->>CE: fulfill! agreement

    CE->>Settlement: complete!(payer_balance, recipient_balance)
    Settlement->>PayerBal: settle_to!(recipient_balance, c3_amount, lock_ref:)
    PayerBal->>PayerBal: locked_millitokens -= amount
    PayerBal->>Lock: find_by(lock_ref).settle!
    Lock-->>Lock: status: settled, settled_at: now
    PayerBal->>RecipBal: credit!(c3_amount)
    RecipBal->>RecipBal: available_millitokens +=\nlifetime_earned_millitokens +=
    Settlement->>Token: create!(earner: recipient,\ncontribution_type: :volunteer,\nsource_ref: "settlement:{id}")
    Settlement-->>Settlement: status: completed, c3_token_id set

    CE-->>Payer: "X Tree Seeds were exchanged."
    CE-->>Provider: "X Tree Seeds have been exchanged. Your balance has been updated."
```

**Records created/modified:**

| Record | Field changes |
|---|---|
| `C3::Balance` (payer, updated) | locked_millitokens -= |
| `C3::Balance` (recipient, updated) | available_millitokens +=, lifetime_earned_millitokens += |
| `C3::BalanceLock` (updated) | status: settled, settled_at |
| `C3::Token` (new) | earner: recipient, contribution_type: volunteer, source_ref: "settlement:{id}" |
| `Joatu::Settlement` (updated) | status: completed, c3_token_id, completed_at |
| `Joatu::Agreement` (updated) | status: fulfilled |

---

## Flow 5: Settlement Cancel

**Plain language:** If either party cancels the agreement before it's fulfilled, the reserved Tree Seeds are immediately returned to the payer's available balance. Nothing is lost; the reservation is simply lifted.

```mermaid
sequenceDiagram
    actor Payer
    participant CE as CE
    participant Settlement as Joatu::Settlement
    participant Balance as C3::Balance (Payer)
    participant Lock as C3::BalanceLock

    Payer->>CE: cancel! agreement

    CE->>Settlement: cancel!(payer_balance)
    Settlement->>Balance: unlock!(c3_amount, lock_ref:)
    Balance->>Balance: locked_millitokens -= amount\navailable_millitokens += amount
    Balance->>Lock: find_by(lock_ref).release!
    Lock-->>Lock: status: released, settled_at: now
    Settlement-->>Settlement: status: cancelled, completed_at: now

    CE-->>Payer: "X Tree Seeds have been returned to your balance."
    CE-->>Provider: "The Tree Seeds reservation was released."
```

**Records created/modified:**

| Record | Field changes |
|---|---|
| `C3::Balance` (payer, updated) | locked_millitokens -=, available_millitokens += |
| `C3::BalanceLock` (updated) | status: released, settled_at |
| `Joatu::Settlement` (updated) | status: cancelled, completed_at |
| `Joatu::Agreement` (updated) | status: cancelled |

---

## Flow 6: Lock Expiry (Automatic)

**Plain language:** If an agreement is accepted (locking Tree Seeds) but never fulfilled or cancelled — for example, if the peer platform goes offline — the locked Tree Seeds are automatically returned after 24 hours. No Tree Seeds are ever permanently frozen.

```mermaid
sequenceDiagram
    participant Job as ExpireBalanceLocksJob\n(runs every 15 min)
    participant Lock as C3::BalanceLock
    participant Balance as C3::Balance

    Job->>Lock: Find pending locks where expires_at < now
    loop For each expired lock
        Lock->>Lock: expire!
        Lock->>Balance: unlock!(millitokens / MILLITOKEN_SCALE)
        Balance->>Balance: locked_millitokens -= amount\navailable_millitokens += amount
        Lock-->>Lock: status: expired, settled_at: now
    end

    Note over Job: No notification currently sent on expiry.\nBalance silently restored.\nLock record is permanent audit trail.
```

**Records modified:**

| Record | Field changes |
|---|---|
| `C3::Balance` (payer, updated) | locked_millitokens -=, available_millitokens += |
| `C3::BalanceLock` (updated) | status: expired, settled_at |

---

## Flow 7: Cross-Platform Lock (Remote Payer)

**Plain language:** When a payer on one platform wants to accept a C3-priced offer from a provider on a different platform, their borgberry node first requests a lock on their home platform's CE. The lock reference is then included in the settlement when the service completes, proving the C3 was reserved before the exchange.

```mermaid
sequenceDiagram
    actor Operator as borgberry Operator (payer's node)
    participant CLI as borgberry CLI
    participant HomeCE as Payer's Home CE
    participant PeerCE as Provider's CE Platform

    Note over Operator,PeerCE: Payer is on Platform A; Provider is on Platform B\nPlatformConnection must allow_c3_exchange on both sides

    Operator->>CLI: borgberry seed c3-lock\n--payer-did did:key:payerDID\n--c3-amount 3.0\n--agreement-ref joatu:agreement-uuid\n--ce-url https://platform-a.internal

    CLI->>CLI: checkNetworkSafety(ce_base_url)
    CLI->>HomeCE: POST /federation/c3/lock_requests\n{payer_did, c3_millitokens, agreement_ref}

    HomeCE->>HomeCE: Find payer by borgberry_did\nCheck C3::Balance.available ≥ amount
    alt Insufficient balance
        HomeCE-->>CLI: 402 {error: "Insufficient Tree Seeds balance"}
    end
    HomeCE->>HomeCE: balance.lock!(c3_amount,\nagreement_ref, source_platform)
    HomeCE-->>CLI: 200 {lock_ref: "uuid", c3_millitokens}

    Note over Operator,PeerCE: Later — when service is delivered —\ninclude lock_ref in the settlement

    Operator->>CLI: borgberry seed c3-settle\n--payer-did ...\n--earner-did ...\n--lock-ref uuid\n--c3-amount 3.0

    CLI->>PeerCE: POST /federation/c3/token_seeds\n{earner_did, payer_did, lock_ref, c3_millitokens}

    PeerCE->>PeerCE: Verify BalanceLock exists for payer_did+lock_ref\nApply to recipient balance
    PeerCE-->>CLI: 201 {applied: true}
```

**Records created/modified:**

| Record | Field changes |
|---|---|
| `C3::Balance` (payer, on home CE) | available_millitokens -=, locked_millitokens += |
| `C3::BalanceLock` (new, on home CE) | lock_ref, source_platform, millitokens, expires_at |
| `C3::TokenSeed` (new, on peer CE) | earner_did, payer_did, lock_ref, c3_millitokens |
| `C3::Token` (new, on peer CE) | federated token for recipient |
| `C3::Balance` (recipient, on peer CE) | available_millitokens += |

---

## Flow 8: Fleet Registration

**Plain language:** Before borgberry nodes can communicate securely with each other and with CE platforms, each node must register itself. This tells the community platform: "This node exists, here is its address, and here is its public encryption key." After registration, all nodes can find each other and set up encrypted channels.

```mermaid
sequenceDiagram
    actor Operator as Operator
    participant CLI as borgberry CLI
    participant Daemon as borgberry Daemon (optional)
    participant CE as CE Fleet API

    Note over Operator,CE: BORGBERRY_CE_FEDERATION_TOKEN must be set as env var

    Operator->>CLI: borgberry seed fleet-register\n[--node-id bts-7]\n[--headscale-ip 100.64.0.8]\n[--lan-ip 10.45.0.8]

    CLI->>CLI: checkNetworkSafety(ce_base_url)

    alt Daemon running
        CLI->>Daemon: LocalPublicKeyBase64()\n(durable Noise X25519 key)
    else Daemon offline
        CLI->>CLI: Generate ephemeral Noise key\n(warn: re-run after daemon starts)
    end

    CLI->>CE: POST /api/v1/fleet/nodes\n{node_id, node_category,\n headscale_ip, lan_ip,\n borgberry_port, safety_tier,\n borgberry_noise_public_key_base64}

    CE->>CE: Find or create FleetNode\nStore noise key in\nservices['inem']['noise_public_key_base64']
    CE-->>CLI: 200/201 {status: registered, node: {...}}

    CLI-->>Operator: Node registered.\nPeer nodes can now route INEM\nmessages to this node.

    Note over Operator,CE: After all nodes register:\nINEM mesh is ready for encrypted C3 federation\nborgberry can route c3-settle via INEM
```

**Records created/modified:**

| Record | Field changes |
|---|---|
| `FleetNode` (new or updated) | node_id, headscale_ip, lan_ip, borgberry_port, node_category, safety_tier, services.inem.noise_public_key_base64 |
