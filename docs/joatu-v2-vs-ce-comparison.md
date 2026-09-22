# Joatu: Alpha v2 vs Community Engine Rails — Design Comparison

> **Reference repos**
> - Alpha v2: `github.com/joatuapp/joatu-v2` (archived, local clone at `partners/joatu-v2`)
> - CE Rails: `better-together-org/community-engine-rails` (this repo)

---

## 1. Offer / Request Data Model

### v2 — Single-table STI with dual discriminators

```mermaid
erDiagram
    offers_and_requests {
        string type         "STI column: Offer::SkillsAndTime etc."
        string offer_or_request  "redundant: 'offer' or 'request'"
        integer user_id
        integer pod_id      "nullable — nil means global"
        string title
        text description
    }
    users {
        integer caps_cents  "balance denormalized here"
        geometry home_location  "PostGIS st_point from postal_code geocode"
        string postal_code
    }
    pods {
        string name
        geometry focus_area  "PostGIS st_polygon — geographic boundary"
    }
    caps_transactions {
        integer source_id
        string source_type   "polymorphic: User | Organization | CapsGenerator"
        integer destination_id
        string destination_type
        integer caps_cents   "Money gem"
        string caps_currency "default: caps"
    }
    organizations {
        integer caps_cents
    }

    offers_and_requests }o--|| users : "user_id"
    offers_and_requests }o--o| pods : "pod_id (nullable = global)"
    caps_transactions }o--|| users : "source/destination polymorphic"
    caps_transactions }o--o| organizations : "source/destination polymorphic"
```

**STI hierarchy** (all empty subclasses, discriminated by `type` column):

```
OfferOrRequest (abstract, table: offers_and_requests)
├── Offer
│   ├── Offer::SkillsAndTime
│   ├── Offer::Knowledge
│   └── Offer::PhysicalGoods
└── Request
    ├── Request::SkillsAndTime
    ├── Request::Knowledge
    └── Request::PhysicalGoods
```

### CE Rails — Separate tables, shared concern

```mermaid
erDiagram
    better_together_joatu_offers {
        uuid id PK
        string status       "open|matched|fulfilled|closed"
        string urgency      "low|normal|high|critical"
        uuid address_id FK
        uuid target_id      "polymorphic scope (any BT entity)"
        string target_type
        uuid creator_id FK
        bigint c3_price_millitokens  "optional C3 pricing signal"
        string c3_price_currency     "default: C3"
    }
    better_together_joatu_requests {
        uuid id PK
        string status
        string urgency
        uuid address_id FK
        uuid target_id
        string target_type
        uuid creator_id FK
        bigint c3_budget_millitokens  "max willing to pay in C3"
        string c3_budget_currency
    }
    better_together_joatu_agreements {
        uuid id PK
        uuid offer_id FK
        uuid request_id FK
        string status       "pending|accepted|rejected"
        text terms
        string value
    }
    better_together_joatu_response_links {
        uuid id PK
        string source_type
        uuid source_id      "polymorphic: Offer or Request"
        string response_type
        uuid response_id    "polymorphic: the other side"
        uuid creator_id FK
    }
    better_together_joatu_offers ||--o{ better_together_joatu_agreements : "offer_id"
    better_together_joatu_requests ||--o{ better_together_joatu_agreements : "request_id"
    better_together_joatu_offers ||--o{ better_together_joatu_response_links : "source/response (polymorphic)"
    better_together_joatu_requests ||--o{ better_together_joatu_response_links : "source/response (polymorphic)"
```

---

## 2. Community Scoping

| Dimension | v2 `Pod` | CE Rails `target` |
|-----------|----------|-------------------|
| What it is | Explicit `Pod` model with PostGIS polygon `focus_area` | Polymorphic FK on Offer/Request (`target_type`/`target_id`) |
| Geographic | Yes — `ST_Contains(focus_area, user.home_location)` | No geographic component |
| Discovery | `best_for_user` geocodes postal code to PostGIS point | Association to Platform or Community by UUID |
| Scope semantics | `pod_id: nil` = global visibility | `target_id: nil` = unscoped |
| Null object | `UncreatedPod.new` returned when user has no pod | Any BT entity (Platform, Community, Event) |

```mermaid
graph LR
    subgraph "v2: Geographic Pod Scoping"
        U1[User\npostal_code → home_location point] -->|ST_Contains| P1[Pod\nfocus_area polygon]
        P1 --> O1[Offer pod_id = nil\nglobal]
        P1 --> O2[Offer pod_id = 3\nlocal to pod]
    end

    subgraph "CE: Polymorphic Entity Scoping"
        U2[Person] --> Plat[Platform]
        U2 --> Comm[Community]
        Plat --> O3[Offer target = Platform]
        Comm --> O4[Offer target = Community]
        O5[Offer target = nil\nunscoped]
    end
```

---

## 3. Local Currency

This is the most substantive architectural difference.

### v2 — Caps (JoatUnits): assigned from a system mint

```mermaid
graph TD
    CG["CapsGenerator.instance\n(singleton system mint)"]
    U1[User\ncaps_cents: 500]
    U2[User\ncaps_cents: 300]
    Org[Organization\ncaps_cents: 1000]
    T1["CapsTransaction\nsource: CapsGenerator\ndestination: User\ncaps_cents: 500"]
    T2["CapsTransaction\nsource: User A\ndestination: User B\ncaps_cents: 100"]

    CG -->|creates caps from thin air| T1
    T1 -->|credits| U1
    U1 -->|peer transfer| T2
    T2 -->|credits| U2

    style CG fill:#fef9c3,stroke:#ca8a04
```

**Key characteristics:**
- Balance stored **directly on `users.caps_cents`** (and `organizations.caps_cents`) — no wallet model
- `CapsTransaction` is a double-entry ledger row — `source` and `destination` are both polymorphic
- `CapsGenerator.instance` (singleton) acts as the system mint — creates caps for community activities (garden planting, teaching classes) without a real source
- Uses `money-rails` gem with `monetize :caps_cents` — currency is `"caps"`, formatted as money
- `Profile.accepted_currencies` JSON field — users declare which currencies they accept

### CE Rails — C3 (Tree Seeds 🌱): earned through contribution

```mermaid
graph TD
    subgraph "Borgberry Fleet Layer"
        Node[Fleet::Node\nbts-0 / bts-7 / jens-pc]
        Job[AgentJobResult\ntranscription / inference / embed]
        Node -->|ran| Job
    end

    subgraph "C3 Earning"
        Job -->|POST /api/v1/c3/contributions| API[CE API]
        Rate[C3::ExchangeRate\ncompute_gpu: 1.5 C3/gpu_hour]
        API -->|create| Token[C3::Token\nstatus: pending → confirmed\nc3_millitokens: 18750]
        API -->|credit| Bal[C3::Balance\navailable_millitokens += 18750]
        Rate -->|rates| API
    end

    subgraph "Joatu C3 Exchange (optional pricing)"
        Offer[Joatu::Offer\nc3_price_millitokens: 5000\n= 0.5 C3]
        Req[Joatu::Request\nc3_budget_millitokens: 10000\n= 1.0 C3]
        Bal -->|spend| Offer
        Bal -->|budget| Req
    end

    style Token fill:#dcfce7,stroke:#22c55e
    style Bal fill:#dcfce7,stroke:#22c55e
```

**Key characteristics:**
- Balance in a **dedicated `C3::Balance` model** (not denormalized onto Person)
- `C3::Token` records each earning event with `source_ref` (job ID), `contribution_type`, units, duration
- Stored as **integer millitokens** (1 C3 = 10,000 millitokens) — no Money gem, no float arithmetic
- C3 is **earned** through compute work (transcription, GPU inference, video encode) — there is no mint
- `C3::ExchangeRate` table maps contribution type → C3 per unit
- Joatu C3 pricing (`c3_price_millitokens` / `c3_budget_millitokens`) is **optional signalling** — not yet a forced ledger debit/credit

| Dimension | v2 Caps | CE C3 |
|-----------|---------|-------|
| Creation mechanism | `CapsGenerator` singleton (from thin air) | Borgberry compute jobs (earned) |
| Balance storage | Denormalized on `users`/`organizations` | Separate `C3::Balance` model |
| Ledger | `CapsTransaction` double-entry | `C3::Token` event log + `C3::Balance` running total |
| Currency type | Money gem, `caps_cents`, `"caps"` currency | Integer millitokens, no Money gem |
| Joatu integration | Implicit (user's balance visible in profile) | Optional `c3_price_millitokens` columns on offers/requests |
| Governance weight | Unclear — not documented | Explicitly **excluded** (one member one vote) |

---

## 4. Matchmaking

| Dimension | v2 | CE Rails |
|-----------|-----|---------|
| Mechanism | None — user browses `available_to(user)` scope | `Matchmaker` service (category + target overlap) |
| Recording | Nothing persisted | `ResponseLink` model — deduplicates, auditable |
| Notifications | None | `MatchNotifier` to both creators on new pairing |
| Initiated by | User browsing | Automatic on Offer/Request create + manual via `respond_with_offer/request` UI flow |

```mermaid
sequenceDiagram
    participant User
    participant CE as CE Rails
    participant MM as Matchmaker
    participant DB

    Note over User,DB: CE Rails — automatic match notification
    User->>CE: POST /exchange/offers (new offer)
    CE->>MM: Matchmaker.match(offer)
    MM->>DB: SELECT requests WHERE categories overlap AND target matches
    DB-->>MM: [request_1, request_2]
    MM-->>CE: matches found
    CE->>DB: MatchNotifier → request creators
    CE-->>User: offer created + matches notified

    Note over User,DB: v2 — user manually browses
    User->>CE: GET /offers (browse list)
    CE->>DB: available_to(user.pod).paginate
    DB-->>CE: all pod-visible offers
    CE-->>User: list (no automatic match, no notification)
```

---

## 5. Agreement / Fulfillment Model

| Dimension | v2 | CE Rails |
|-----------|-----|---------|
| Model exists | No | Yes — `Joatu::Agreement` |
| State machine | N/A | `pending → accepted` or `pending → rejected` (terminal) |
| Uniqueness enforcement | N/A | DB unique index on `[offer_id, request_id]` + only one accepted per offer + one per request |
| Mutual status update | N/A | `accept!` closes both offer and request in one transaction |
| Notification | N/A | `AgreementNotifier` (create) + `AgreementStatusNotifier` (state change) |

---

## 6. Search

| Dimension | v2 | CE Rails |
|-----------|-----|---------|
| Engine | `pg_search` gem (`pg_search_scope`) | Custom `SearchFilter` service using Arel |
| Language support | `french`/`english` dictionary-aware tsearch | Mobility translation columns (any locale) |
| Fields searched | `title` (weight A) + `description` (weight C) | Translated `name` + ActionText `description` body + category names |
| Accent handling | `ignore_accents: true` | Not explicitly configured |
| Full-text ranking | pg_search weighted rank | None — ordering by `created_at` only |

---

## 7. Architecture and Deployment Model

| Dimension | v2 | CE Rails |
|-----------|-----|---------|
| App type | Monolithic Rails app | Rails engine (gem), multi-tenant |
| Auth | Devise on `User` (with profile separation) | Devise on `User` + separate `Person` model |
| Geographic features | PostGIS (`focus_area`, `home_location`, geocoding) | None (address FK only) |
| Real-time | Mailboxer (Conversation/Message models) | ActionCable conversations, Noticed notifications |
| API | None documented | Full JSONAPI v1 (`joatu_offers`, `joatu_requests`, `joatu_agreements`) |
| Multi-tenancy | Pod = one community per deployment | `target` polymorphic = any number of platforms/communities |
| Ruby version | 2.4.5 | 3.x (3.4.4 in active CI) |

---

## 8. What CE Rails Adds That v2 Never Had

1. **`Agreement` model** — explicit, auditable contract between offer and request creators with state machine
2. **`ResponseLink` model** — records and deduplicates offer↔request pairings before an agreement is formed
3. **`Matchmaker` service** — automatic match discovery at create time
4. **JSONAPI v1** — full REST API for mobile and external clients
5. **Pundit policies** — per-action, per-user authorization (v2 had none visible in models)
6. **Internationalization** — Mobility-translated `name` + ActionText `description` in all locales
7. **C3 integration** — compute-earned currency tied to borgberry fleet jobs (vs. assigned caps)
8. **`urgency` field** — priority signalling on offers/requests
9. **`address` association** — location scoping without requiring PostGIS
10. **`ResponseLinkable` concern** — structured UI flow for responding to the other side

---

## 9. What v2 Had That CE Rails Does Not (Yet)

1. **PostGIS geographic scoping** — pod polygon containment, user geocoding by postal code
2. **`CapsGenerator` mint** — system-assigned currency for community activities (garden, teaching)
3. **`User.caps_cents` balance** — directly spendable money balance on the user record
4. **`OrganizationMembership`** — organizations also hold caps (CE has Platform but no caps on it)
5. **Bilingual search ranking** — pg_search with French/English dictionaries, weighted fields
6. **`Profile.accepted_currencies`** — user preference for which currencies they'll accept in exchanges
7. **`PodMembership.membership_types`** — pg array column allowing multiple membership types per user/pod

---

## Summary Diagram

```mermaid
graph TD
    subgraph "joatu-v2 (2017 design)"
        V_STI["OfferOrRequest\nSTI single table\n+ dual discriminators"]
        V_Pod["Pod\nPostGIS polygon\nbest_for_user geo query"]
        V_Caps["CapsTransaction\nMoney gem\nCapsGenerator mint"]
        V_User["User\ncaps_cents denormalized\nhome_location PostGIS"]
        V_STI --- V_Pod
        V_Pod --- V_User
        V_User --- V_Caps
    end

    subgraph "CE Rails (2024–2026)"
        CE_Offer["Joatu::Offer\nseparate table\nExchange concern"]
        CE_Request["Joatu::Request\nseparate table\nExchange concern"]
        CE_Agreement["Joatu::Agreement\nstate machine\nacceptance transaction"]
        CE_Link["ResponseLink\npairing record\ndedup index"]
        CE_Match["Matchmaker service\nauto-notify on create"]
        CE_C3["C3::Token + Balance\nearned from compute\nnot assigned"]
        CE_Fleet["Fleet::Node\nborgberry heartbeat"]

        CE_Offer --- CE_Agreement
        CE_Request --- CE_Agreement
        CE_Offer --- CE_Link
        CE_Request --- CE_Link
        CE_Match --> CE_Link
        CE_Fleet --> CE_C3
        CE_C3 -.->|"optional pricing signal"| CE_Offer
        CE_C3 -.->|"optional budget signal"| CE_Request
    end

    V_Caps -.->|"concept lives on\nas optional C3 pricing"| CE_C3
    V_STI -.->|"split into concern-based\nseparate tables"| CE_Offer
    V_Pod -.->|"generalised to\npolymorphic target"| CE_Offer

    style CE_C3 fill:#dcfce7,stroke:#22c55e
    style CE_Fleet fill:#dbeafe,stroke:#3b82f6
    style V_Caps fill:#fef9c3,stroke:#ca8a04
    style V_Pod fill:#fef9c3,stroke:#ca8a04
```
