# Borgberry CE Integration — Fleet Mesh + C3 Community Contribution Token

---

## What This Is

This branch adds the Community Engine-side infrastructure that lets CE act as a **coordination layer for the borgberry fleet mesh** and the **C3 Community Contribution Token (🌱 Tree Seed)**.

The current release-bound scope is:

- CE stores fleet node registration and heartbeat state.
- each fleet node has **one current owner** via `Fleet::NodeOwnership`; owners can currently be a `Person` or `Community`.
- Borgberry contribution events credit the **node owner’s** C3 balance, not the node record itself.
- fleet-write and contribution-write endpoints are restricted to a **trusted OAuth application or a platform manager**.
- self-service reads remain available for a person’s own DID-based balance and Borgberry profile.

Three concerns are wired together:

| Concern | What it enables |
|---------|----------------|
| **Fleet mesh** | Borgberry nodes register with a CE platform, send heartbeats, and expose a current owner for settlement and payout flows |
| **Job tracking** | Fleet job outputs can be stored in CE as `AgentJobResult` records and linked back to the node that ran them |
| **C3 tokens** | Compute contributions earn C3 millitokens; balances are tracked per holder; Joatu offers/requests can optionally price in C3 |

---

## Schema — New and Modified Tables

```mermaid
erDiagram
    Person {
        string borgberry_did "W3C DID (did:key:z6Mk...) — unique, nullable"
    }

    PlatformConnection {
        string noise_public_key "INEM Noise protocol pubkey — unique, nullable"
        boolean routing_allowed "whether this connection may route traffic"
    }

    Fleet__Node {
        uuid id PK
        string node_id UK "e.g. bts-0, bts-7, jens-pc"
        string node_category "cat1 | cat2 | cat3"
        string headscale_ip
        string lan_ip
        integer borgberry_port "default 8790"
        jsonb hardware "cpu, ram, gpu_type, disk"
        jsonb compute "ollama_models, transcribe, embed flags"
        jsonb services "running service registry"
        string safety_tier "T0 | T1 | T2 | T3"
        boolean online "live heartbeat status"
        datetime last_seen_at
        datetime registered_at
        uuid platform_id FK
    }

    Fleet__NodeOwnership {
        uuid id PK
        uuid node_id FK "single current ownership row per node"
        uuid owner_id FK "polymorphic — Person, Community, or future owner"
        string owner_type
    }

    AgentJobResult {
        uuid id PK
        string job_id UK
        string job_type "transcription | inference | embedding | ..."
        string status "pending | running | completed | failed"
        string source_system "borgberry"
        jsonb input_payload
        jsonb output_payload
        datetime started_at
        datetime completed_at
        uuid fleet_node_id FK
        uuid submitter_id FK "polymorphic"
    }

    C3__ExchangeRate {
        uuid id PK
        integer contribution_type UK "enum: compute_cpu=0, compute_gpu=1, ..."
        string contribution_type_name
        decimal rate "C3 per unit (e.g. 1.5 C3/gpu_hour)"
        string unit_name "cpu_hour | gpu_hour | video_minute | ..."
        string unit_label "human-readable"
        boolean active
    }

    C3__Token {
        uuid id PK
        integer contribution_type
        string contribution_type_name
        bigint c3_millitokens "1 C3 = 10_000 millitokens"
        string source_ref "job_id, PR number, CE event ID"
        string source_system
        decimal units
        decimal duration_s
        jsonb metadata
        string status "pending | confirmed | disputed | settled"
        datetime emitted_at
        datetime confirmed_at
        uuid earner_id FK "polymorphic — Person or AgentActor"
        uuid community_id FK
    }

    C3__Balance {
        uuid id PK
        bigint available_millitokens
        bigint locked_millitokens "reserved for in-flight Joatu exchanges"
        bigint lifetime_earned_millitokens "monotonically increasing"
        uuid holder_id FK "polymorphic"
        uuid community_id FK
    }

    JoatuOffer {
        bigint c3_price_millitokens "optional — offer priced in C3"
        string c3_price_currency "default: C3"
    }

    JoatuRequest {
        bigint c3_budget_millitokens "optional — max willing to pay in C3"
        string c3_budget_currency "default: C3"
    }

    Fleet__Node ||--o{ AgentJobResult : "ran"
    Fleet__Node }o--|| C3__Token : "earner (polymorphic)"
    Fleet__Node ||--|| Fleet__NodeOwnership : "has current owner"
    Person ||--o{ Fleet__NodeOwnership : "owns"
    Community ||--o{ Fleet__NodeOwnership : "owns"
    Person ||--o{ C3__Token : "earner (polymorphic)"
    Person ||--o{ C3__Balance : "holder (polymorphic)"
    C3__Token }o--|| C3__ExchangeRate : "contribution_type"
    C3__Balance ||--o{ C3__Token : "balance ← tokens"
    JoatuOffer ||--o| C3__Balance : "spend from balance"
    JoatuRequest ||--o| C3__Balance : "budget from balance"
```

---

## API Endpoints Added

```
POST /api/v1/fleet/nodes                      register or upsert a node
GET  /api/v1/fleet/nodes                      list nodes (optional ?online=true)
GET  /api/v1/fleet/nodes/:node_id             show single node
POST /api/v1/fleet/nodes/:node_id/heartbeat   update last_seen_at + capabilities

GET  /api/v1/c3/contributions                 list earned C3 token records
POST /api/v1/c3/contributions                 record a new contribution event
GET  /api/v1/c3/balance                       get current balance for a node owner
GET  /api/v1/c3/network_balance               aggregate balances for a borgberry DID
GET  /api/v1/borgberry/profile                return the authenticated person's Borgberry DID profile
POST /api/v1/joatu_agreements/:id/cancel      unwind a pending C3 settlement for an accepted agreement
```

### Effective auth contract

| Endpoint family | Allowed callers |
|---|---|
| `POST /api/v1/fleet/nodes*`, `POST /api/v1/c3/contributions`, `GET /api/v1/c3/balance`, `GET /api/v1/c3/contributions` | Trusted OAuth application with the required read/write scope, or a platform manager |
| `GET /api/v1/c3/network_balance` | The person who owns the queried DID, or a platform manager |
| `GET /api/v1/borgberry/profile` | Any authenticated user with a linked person; OAuth bearer calls also need `read` scope |

---

## Data Flow — Fleet Heartbeat Cycle

```mermaid
sequenceDiagram
    participant B as Borgberry Node<br/>(bts-0 / bts-7 / jens-pc)
    participant A as CE API<br/>/api/v1/fleet/nodes
    participant DB as CE Database<br/>fleet_nodes table
    participant J as Borgberry Job Runner<br/>borgberry_job_runner.py

    B->>A: POST /fleet/nodes { node_id, hardware, compute }
    A->>DB: upsert Fleet::Node (find_or_initialize_by node_id)
    DB-->>A: node record
    A-->>B: { status: "ok", node: {...} }

    loop every ~60s
        B->>A: POST /fleet/nodes/bts-0/heartbeat { hardware, services }
        A->>DB: node.mark_online! + update capabilities
        DB-->>A: updated record
        A-->>B: { status: "ok", last_seen_at: "..." }
    end

    J->>A: POST /c3/contributions { contribution_type: "compute_gpu", units: 12.5, source_ref: "job:abc123" }
    A->>DB: C3::Token.find_or_create_by! (status: confirmed, idempotent by source_system + source_ref)
    A->>DB: C3::Balance.credit! (available += earned owner balance)
    DB-->>A: token + balance
    A-->>J: { status: "ok", c3_amount: 18.75 }
```

---

## C3 Token Lifecycle

```mermaid
stateDiagram-v2
    [*] --> confirmed : borgberry contribution accepted\nPOST /c3/contributions
    [*] --> pending : other provisional source\n(optional model state)
    pending --> disputed : contributor flags\ndiscrepancy

    confirmed --> settled : Joatu exchange\ncompleted

    disputed --> confirmed : dispute resolved
    disputed --> settled : dispute resolved +\nexchange completed

    confirmed --> [*]
    settled --> [*]

    note right of confirmed
        Borgberry contributions land here directly
        and immediately credit available balance
    end note

    note right of settled
        C3::Balance.locked decremented
        Joatu agreement finalised
    end note
```

### Settlement / unwind contract

- accepting a C3-priced agreement creates a pending `Joatu::Settlement` tied to a `C3::BalanceLock`;
- fulfilling that agreement consumes the exact pending lock and marks the settlement `completed`;
- cancelling an accepted agreement consumes the exact pending lock via `unlock!` and marks the settlement `cancelled`;
- missing, stale, or mismatched `lock_ref` values now fail closed instead of silently no-oping.

---

## Relationship to Other `release/0.11.0-notes` Contributions

This branch is the **fleet infrastructure layer** that the governed-agent and robot models (from other branches in this release) will use as their compute context.

```mermaid
graph TD
    subgraph "release/0.11.0-notes — branches merged this session"
        R[copilot/pr-1494<br/>Robot + GovernedAgent<br/>identity helpers]
        M[feat/membership-requests<br/>Platform membership request<br/>API + admin routes]
        Q[codex/pr-1244-fixes<br/>PolicySpec + CI quality<br/>gates + test credentials]
        B[feat/borgberry-c3-ce-integration<br/>THIS BRANCH<br/>Fleet + C3 infrastructure]
    end

    subgraph "CE Models"
        Person["Person\n+ borgberry_did\n+ borgberry_did_raw accessor"]
        Robot["Robot\n.resolve / .authenticate_access_token\n.available_for_platform\n#governed_agent_key"]
        FleetNode["Fleet::Node\nnode registry\nheartbeat + capabilities"]
        FleetNodeOwnership["Fleet::NodeOwnership\nsingle current polymorphic owner"]
        C3Token["C3::Token\nearned contribution event"]
        C3Balance["C3::Balance\nrunning millitoken totals"]
        AgentJobResult["AgentJobResult\nSeedable job output record"]
    end

    subgraph "Borgberry External Layer"
        NodeProcess["borgberry node process\n(Go binary, port 8790)"]
        JobRunner["borgberry_job_runner.py\n(transcription/inference/embed)"]
        FleetDispatch["borgberry_fleet_dispatch.py\n(capability matching)"]
    end

    R --> Robot
    M --> Person
    B --> Person
    B --> FleetNode
    B --> FleetNodeOwnership
    B --> C3Token
    B --> C3Balance
    B --> AgentJobResult

    NodeProcess -->|"POST /fleet/nodes/heartbeat"| FleetNode
    JobRunner -->|"POST /c3/contributions"| C3Token
    FleetDispatch -->|"GET /fleet/nodes?online=true"| FleetNode
    Robot -->|"future: governs AgentActor\nwho earns C3"| C3Token
    Person -->|"holds"| C3Balance
    FleetNode -->|"ran"| AgentJobResult

    style B fill:#e6f3ff,stroke:#3b82f6
    style R fill:#f0fdf4,stroke:#22c55e
    style M fill:#f0fdf4,stroke:#22c55e
    style Q fill:#f0fdf4,stroke:#22c55e
```

### Key design decisions

**Why C3 is NOT governance weight**
`C3::Token` and `C3::Balance` are intentionally isolated from the `GovernedAgent` / `GovernanceParticipant` models. C3 rewards compute contribution — it does not buy voting power. Governance remains one-member one-vote (co-op principle).

**Why millitokens**
Storing `bigint` millitokens (1 C3 = 10,000 millitokens) avoids floating-point rounding in balance arithmetic. All credit/debit operations use integer increments.

**Why idempotent migrations**
Every migration guards with `unless table_exists?` / `unless column_exists?`. This lets the migrations run safely on hosts where a previous partial apply may have left some tables present.

**Why `Fleet::Node` belongs to CE, not just borgberry**
The borgberry registry is the source of truth for live state, but CE needs to store historical job results (`AgentJobResult`) and associate them with Persons, Communities, and Joatu exchange records. The CE `fleet_nodes` table is a **capability mirror** — borgberry pushes to it, CE reads from it.

---

## Migration Checklist

Run these in order on any affected database:

```bash
rails db:migrate VERSION=20260407000100  # borgberry_did on Person
rails db:migrate VERSION=20260407000200  # noise_public_key on PlatformConnection
rails db:migrate VERSION=20260407000400  # fleet_nodes table
rails db:migrate VERSION=20260407000500  # agent_job_results table
rails db:migrate VERSION=20260407001000  # c3_tokens, c3_balances, c3_exchange_rates
rails db:migrate VERSION=20260407001100  # c3_price/budget on joatu offers/requests
# or simply:
rails db:migrate
```

All migrations are safe to run twice — idempotency guards prevent duplicate columns/tables.
