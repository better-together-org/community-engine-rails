# Seed Packet Protocol 2.0

Seed packs are the installable bundles of Community Engine data (roles, pages, navigation, events, files). Protocol 2.0 is the portable format that carries them: a directory or `.tar.gz` that any host app can verify, plan and plant on a chosen platform without a new Ruby importer per packet. It is additive. Version 1.0 envelopes stay valid and keep loading through `Seed.load_seed`.

This document is the specification and the record of why it exists. The validator in this PR (`BetterTogether::Seeds::Protocol::Validator`) enforces the structure; the registry, planner, applier and blob transport follow in later PRs.

## Where this came from

There was never a single written protocol. The design was reconstructed from these sources and reconciled here.

| Source | What it contributed |
|---|---|
| Current repo: `Seed`, `Seedable`, `SeedPlanting`, `config/seeds/seed_example.yml`, [Seed Catalog and Seed Plantings](seed_catalog_and_plantings_system.md) | The envelope (`better_together:` root, `version`, `seed:`), safe YAML loading, size and path guards, plantings audit rows |
| `docs/implementation/current_plans/seedable_system_implementation_plan.md` | Three phases: security, validation and conflict handling, dependencies and rollback |
| Seed packs design (Copilot session, 2026-03-27/28) | The `seed_pack` metadata block, `PackImportService`, `PackInstaller`, `InstallerRegistry`, structured result, one transaction per pack, dependency rules by pack identifier, builder-to-pack extraction map, setup wizard `seed_pack_selection` step |
| CE Seed Protocol plan (Codex, 2026-03-11) | Seed as the CE-to-CE wire envelope, package classes (structural, platform-shared, person-linked private), dependency metadata |
| Billing planters (`feature/billing`) | Add-only idempotent reruns, explicit platform target, natural-key references that fail the whole plant before any write |
| NLO municipal loaders | Dry-run by default, source checksums, attach-once blobs with licence recorded |

### Reconciliation rule

The seed-packs names win. Protocol 2.0 keeps `seed_pack` (block), `PackImportService`, `PackInstaller` and `InstallerRegistry`, and adds the missing pieces on top: manifest, blobs, platform target, references, dry-run, provenance. `seed.type` stays `BetterTogether::Seed` because it is the STI column; pack identity lives in `seed.identifier` and `seed_pack`. "Seed pack" is the human-facing term. "Packet" names the on-disk transport of one pack.

## Packet layout

```
my-packet/
  packet.yml          envelope (this section)
  MANIFEST.json       sha256, size, media type, owner for every other file
  MANIFEST.json.sig   optional detached signature (key id in seed.origin.signing_key_id)
  records/pages.yml   one file per record type, listed in packet.records
  blobs/<sha256>      file bytes, content addressed
```

A `.tar.gz` of the directory is equivalent. Readers must reject absolute paths, `..` segments, symlinks and any entry not listed in the manifest.

### packet.yml

```yaml
better_together:
  version: "2.0"
  seed:                      # unchanged from 1.0, plus origin.signing_key_id
    type: "BetterTogether::Seed"
    identifier: "foray-nl-site"
    created_by: "..."
    created_at: "2026-11-13T00:00:00Z"
    description: "..."
    origin: { platforms: [], contributors: [], license: "", usage_notes: "", signing_key_id: "" }
  seed_pack:                 # from the seed packs design
    schema_version: "1.0"
    pack_type: "pages"
    install_tier: "optional" # core | recommended | optional | demo
    dependencies: []         # other pack identifiers; missing ones fail closed
  packet:                    # new in 2.0
    id: "foray-nl-site"
    version: "1.0.0"
    mode: "add_only"         # add_only | upsert | managed
    default_locale: "en"
    locales: ["en", "fr"]
    unsupported_locale_policy: "skip"   # fail | skip | fallback_default
    target: { platform_identifier: "foray" }   # optional hint, never the authority
    records: ["records/pages.yml"]
    manifest: "MANIFEST.json"
  deletes:                   # tombstones, only honoured for records this packet planted
    - { type: page, key: old-page }
```

The platform that receives the packet is always supplied by the caller (`PLATFORM=` in the rake task). If the packet declares `target.platform_identifier` and it differs, the plan reports a conflict. A packet can never choose its own target.

### records/*.yml

```yaml
version: "2.0"
type: page                   # a name in the type registry (C2)
records:
  - key: about/history       # natural key, unique per (platform, type)
    attributes: { slug: history }
    translations: { en: { title: "History" }, fr: { title: "Histoire" } }
    refs: { parent: "page:about" }          # or { type: page, key: about, scope: platform }
    files:
      - { attachment: hero_image, blob: "blobs/<sha256>", filename: hero.png,
          content_type: image/png, checksum: "<sha256>" }
    position: 3
```

References resolve packet-local first, then on the target platform (`scope: platform` skips the packet). An unresolved reference fails the plan before any write.

### Modes

| Mode | Behaviour |
|---|---|
| `add_only` | Create missing records; never touch an existing one, even if unedited |
| `upsert` | Update records the packet planted and nobody edited since; edited ones are reported `skipped_edited` |
| `managed` | Like `upsert`, plus `deletes:` tombstones for records the packet planted and nobody edited |

Edits are detected by comparing the stored fingerprint (sha256 of the canonical record) with the current row.

### Result report

```json
{ "created": 0, "updated": 0, "skipped_edited": 0, "unchanged": 0,
  "errors": [ { "record": "page:about", "field": "/refs/parent", "message": "..." } ] }
```

The validator already produces the same shape (`Report#to_h`): `file`, `record`, `field` (a JSON pointer) and `message`, all errors at once.

## Flow

```mermaid
flowchart TD
  A[Packet dir or tar.gz] --> B[Safe load: path, size, no symlinks]
  B --> C[Validate packet.yml, records, MANIFEST against schemas]
  C --> D[Verify manifest sha256 and optional signature]
  D --> E[Plan: resolve refs, order by dependency, classify create/update/skip/conflict]
  E -->|dry run| F[Report only, nothing written]
  E -->|apply| G[One transaction, savepoint per record]
  G --> H[Provenance and SeedPlanting with per-record outcomes]
```

Steps B and C ship in this PR. D, E and G are C3 and C4.

## Schemas and validator

JSON Schema documents (draft 2020-12) live in `config/seeds/schema/`: `envelope.schema.json`, `records.schema.json`, `manifest.schema.json`. `Seeds::Protocol::Validator` runs them with `Seeds::Protocol::SchemaValidator`, a small in-process validator for the keyword subset the schemas use (the `json-schema` gem is test-only here). On top of the schemas it enforces what a schema cannot: default locale is listed in `locales`, no duplicate record files or keys per type, a blob path equals `blobs/<checksum>`, a pack does not depend on itself. 1.x envelopes pass through the original required-field rules.

## The 16 numbered deficiencies

Found by assessing `github/main`, billing, multi-tenancy, NLO and NLV, then confirmed by building the foray packet. Status says where each is fixed.

| # | Deficiency | Resolution | Status |
|---|---|---|---|
| 1 | No materialization layer: `Seed.import` stores a row, nothing creates records | `PackImportService`, installer registry, applier | registry **in C2**, applier **in C3** |
| 2 | Missing record types (pages with nesting, content blocks, navigation, uploads, events, social accounts, redirects) | Registry entries per type; Redirect model is Track D | registered **in C2** (Flickr added), redirects D1 |
| 3 | No file transport; 10 MB cap applies to the YAML | `blobs/<sha256>`, manifest, streaming reads, per-blob size policy | **fixed in C4** |
| 4 | No cross-record references | `refs` with `type:key` or `{type, key, scope}`, resolved before any write | spec and schema C1, resolver C3 |
| 5 | Idempotency is per planter; Builder identifier has a random suffix; no provenance | Natural `key` per (platform, type); fingerprint, packet id, version, key stored per planted record in `SeedProvenance` | spec C1; `SeedProvenance` table (this PR) |
| 6 | `Seed` is global on (type, identifier); `clear` deletes every platform's data | Required platform target; platform-scoped `Seed` | `Seed` platform-scoped (#2249); `clear` is not part of packets; `Plant` stores one `Seed` envelope row per platform and packet, linked from the `SeedPlanting` |
| 7 | No dry-run or diff | The plan is the dry-run report | **fixed in C3** |
| 8 | No validation schema | JSON Schemas and `Protocol::Validator` | **fixed in C1** |
| 9 | No signature verification | Detached signature over `MANIFEST.json`, key id in `origin` | **fixed in C9**: Ed25519 detached signature, see Signatures below |
| 10 | No partial update or deletion model | `mode` plus `deletes:` tombstones limited to provenance-owned records | spec and schema C1, applier C3 |
| 11 | No versioning or migration semantics | `version` 2.x selects the 2.0 schema, 1.x keeps old rules; `packet.version` per packet; `seed_pack.schema_version` | **fixed in C1** (selection), migrations later |
| 12 | Inconsistent locale handling | `default_locale`, `locales`, `unsupported_locale_policy`, per-record `translations` | **fixed in C1** (declaration and consistency check), policy applied in C3 |
| 13 | No ordering model | `position` per record; apply order is topological by references, then `position` | **fixed in C3** |
| 14 | Errors flatten to strings | `Report` with file, record, field pointer, message; all errors at once | **fixed in C1** |
| 15 | Concurrency only on the `Seed` row | One transaction per packet, advisory lock per (platform, packet id) | **fixed in C3** |
| 16 | `ALLOWED_SEED_DIRECTORIES` blocks host-app directories and uploads | Configurable packet-source allowlist beyond `config/seeds` | **fixed in C4** |

## Integration and conformance (C5)

`Seeds::Plant` now joins the pieces. It accepts a directory or a `.tar.gz` (unpacked to a throwaway directory), verifies `MANIFEST.json` when present, attaches files with `BlobAttacher`, and fails closed when records declare files but no manifest exists. `restrict_sources: true` (used by the rake tasks) limits paths to `PacketSources`. Transport problems appear in the same report as plan errors and nothing is written.

`spec/seeds/golden/conformance_spec.rb` plants packets through `Plant` and covers: empty platform, identical rerun, dry run, two platforms, steward-edited record, missing reference, locale policy, verified blob, tampered blob, missing manifest, tar.gz and the source allowlist.

Platform-scoped `Seed` landed in #2249 (C7, without provenance columns). Held: C6 for billing (lives on the billing branch). Deficiencies 5 and 6 are fixed by `SeedProvenance` and the envelope row written by `Seeds::ProvenanceWriter` (see Provenance below).

## Type registry (C2)

`Seeds::Registry` replaces the per-class `plant` pointers. Each type is declared once with a small DSL and frozen:

```ruby
BetterTogether::Seeds::Registry.register(:upload) do
  model 'BetterTogether::Upload'
  attributes :privacy
  translated :name, :description
  attachment :file
end
```

| DSL | Meaning |
|---|---|
| `model` | The ActiveRecord class |
| `natural_key col` | Column that holds the packet `key`, looked up inside the target platform (default `identifier`) |
| `natural_key col, within: :ref` | Key is unique only inside a parent record (social account within its contact detail) |
| `natural_key by_refs: [:a, :b]` | A join row identified by the records it joins (`page_block`) |
| `attributes`, `translated` | The only fields a packet may write |
| `reference name, to:, optional:` | Reference slots; `to:` lists allowed target types |
| `attachment`, `position`, `sti` | Files, ordering column, and the subclass column for STI types such as content blocks |
| `before_resolve`, `transform`, `after_plant` | Hooks for host-app logic |

`Registry.ordered` returns types in dependency order and raises `DependencyCycle`. `TypeDefinition#find(platform:, key:, parent_refs:)` resolves a key on the target platform only, never globally. A type keyed `within:` (or `by_refs:`) is found through the parent records its own refs name: the planner follows the packet entry's refs (a `social_media_account` reaches its `contact_detail`, which reaches its `contactable`) and the applier takes parents from the records written or located earlier in the same run. A parent that is not in the packet cannot be named by type and key alone, so a ref to such a record fails the plan with a packet error (`was not found in the packet or on the platform`) instead of raising. Host apps register their own types (NLO districts, NLV venues) from an initializer.

Registered: `page`, `content_block`, `page_block`, `navigation_area`, `navigation_item`, `upload`, `event`, `community`, `contact_detail`, `social_media_account`, `platform` (lookup target only). `SocialMediaAccount::PLATFORMS` gains Flickr.

### Findings while registering (added to the numbered list)

| # | Deficiency | Resolution |
|---|---|---|
| 17 | Natural keys are not always a column: social accounts and join rows have none | `within:` and `by_refs:` key kinds |
| 18 | `Page` has no cover or share image attachment, so the page share image needs a model change | Open model work item, not worked around |
| 19 | `Event.identifier` was globally unique (index on `identifier` alone), unlike pages and uploads | Fixed: unique on `(identifier, platform_id)` where `platform_id` is not null, like posts and pages; the Identifier concern already validated per platform. Covered by the two-platform isolation suite |

The registry spec checks each declared attribute is writable on the model, each attachment exists, and each reference points at a registered type, so a drifting model fails CI.

## Signatures (C9)

`MANIFEST.json.sig` is a base64 Ed25519 signature over the exact bytes of `MANIFEST.json`. The manifest lists the sha256 of every other file, so one signature covers the whole packet. `seed.origin.signing_key_id` names the key. A packet never carries the key it is checked against: `Seeds::Signature` looks the id up in keys the host trusts, registered with `Signature.register_key(id, pem)` or placed as `<key_id>.pem` in a directory listed in `BETTER_TOGETHER_SEED_TRUSTED_KEYS_DIR` (colon separated).

| Situation | Result |
|---|---|
| Signature present, trusted key, bytes match | Plant continues |
| Signature present, key id missing, malformed or untrusted | Error, nothing written |
| Signature present, manifest changed or signed by another key | Error, nothing written |
| No signature, `require_signature: false` (default) | Plant continues; integrity still rests on the manifest hashes |
| No signature, `require_signature: true` (`REQUIRE_SIGNATURE=1` on the rake tasks) | Error, nothing written |

The signature is checked before the manifest hashes. Tooling can produce one with `Signature.sign(manifest_bytes, private_key_pem)`. Limits: only Ed25519 is accepted (the `.asc` name in the schema is reserved, not implemented); there is no revocation list or key expiry, so removing a key file or registration is the revocation; GPG and OpenPGP keys are not read.

## Planner and applier (C3)

`Seeds::Plant.call(path:, platform:, apply: false)` loads a packet directory (`Seeds::Packet`: no symlinks, safe YAML, schema validation), plans it (`Seeds::Planner`) and, only with `apply: true` and an error-free plan, writes it (`Seeds::Applier`). It always returns the structured report; a dry run writes nothing, not even a `SeedPlanting`.

```
rake better_together:seeds:plan  PACKET=/path/to/packet PLATFORM=<platform identifier>
rake better_together:seeds:plant PACKET=/path/to/packet PLATFORM=<platform identifier> APPLY=1
```

Planning checks that every attribute and translation is declared writable in the registry, every reference slot is allowed and resolves (packet-local first, then on the target platform), locales follow `unsupported_locale_policy`, the packet's `target.platform_identifier` matches, and `seed_pack.dependencies` are already planted. Records are ordered by reference (Kahn's algorithm, ties by type order, `position`, file order); cycles are errors.

Each record is classified by comparing a flat snapshot of the fields the entry owns (`attr:`, `tr:<locale>:`, `ref:`, `position`) with the record and with the snapshot taken when this packet last planted it:

| Situation | Action |
|---|---|
| No record with that key on the platform | `create` |
| Record already holds the packet values | `unchanged` |
| `add_only`, record differs | `skipped_edited` (existing records are never touched) |
| `upsert` or `managed`, record differs, matches what the packet last planted | `update` |
| Record differs and was edited since, or the packet never planted it | `skipped_edited` |
| `managed` tombstone, record planted by the packet and unedited | `delete` |

Apply takes a per-packet advisory lock (deficiency 15), writes one transaction with a savepoint per record, and rolls the whole packet back if any record errors, reporting every failing record with its field. A `SeedPlanting` row records the outcome; per-record provenance is stored in `SeedProvenance` rows that the next plan reads. Files fail closed per record until blob transport (C4) supplies `attach_files`.

Known limits: lookups of `within:` and `by_refs:` types as references to existing platform records are not supported (packet-local only).

## Sentinels

An attribute value of `$now` is replaced with the time of the plant when the record is **created**. It is not part of the edit comparison and is never rewritten: a rerun, an `upsert` update or a later plant leaves the stored time alone, so the plan stays `unchanged`. Use it for `published_at` and similar stamps. It is the only sentinel; there is no `$now+7d` or per-locale form.

## Navigation as a packet (C6, navigation only)

`config/seeds/better_together/navigation/` is the default header, host, Better Together and footer navigation with the 14 static pages and blocks it links to, as a protocol 2.0 packet (`add_only`, English). It is the first built-in packet and is planted with the rake tasks like any other:

```
rake better_together:seeds:plan  PACKET=config/seeds/better_together/navigation PLATFORM=<identifier>
rake better_together:seeds:plant PACKET=config/seeds/better_together/navigation PLATFORM=<identifier> APPLY=1
```

`spec/seeds/golden/navigation_packet_spec.rb` plants it on an empty platform, reruns it, plants a second platform, checks that a steward-edited page survives, and compares the result item by item and page by page with what `NavigationBuilder` produces on the host platform. `NavigationBuilder` itself is not replaced: the test suite, `db/seeds.rb` and the generate tasks still call it, and switching them to `Seeds::Plant` is a separate change. Billing planters live on `feature/billing` and are not converted here.

Differences from the builder, all deliberate:

- The packet is idempotent. The builder creates the header, About, Home, Subprocessors and Better Together pages again on every run, with random slug suffixes (`about-HuFezy0o6k`), and names two navigation items after those suffixes. The packet uses stable keys and slugs.
- `published_at` is `$now` (see Sentinels): stamped when the page is created, never rewritten on a rerun, like the builder's `Time.zone.now`.
- Position numbers are not copied. The spec compares the order of items within each area and parent, which matches the builder. The builder gives the Contributor Agreements dropdown position 1 because it counts unsaved items, which ties with Privacy Policy; the packet numbers it last and the order is the same.
- The builder cannot build a second platform's navigation (`Identifier has already been taken` across platforms when the item's platform is not yet set at validation). The packet can.
- The two footer contributor links keep the builder's `private` privacy, so the packet matches the builder exactly. Their pages are public, so this looks unintended, but changing it is a product decision made in `NavigationBuilder` first, then here.

### Findings while converting (added to the numbered list)

| # | Deficiency | Resolution |
|---|---|---|
| 20 | `content_block` could not carry `template_path`, and `protected` could not be set, so the built-in pages could not be expressed | `template_path` is writable. `protected` is writable only on types that declare `protectable` in the registry (page, navigation_area, navigation_item); it is off by default for every other type and a packet that sets it elsewhere is rejected. Only plant packets you trust (sign them) |
| 21 | No way to express a relative time such as `published_at: now` | **Fixed**: the `$now` sentinel, see below |
| 22 | The plan and the applied report counted a rerun of join rows (`page_block`) and records keyed by a parent as `create` | **Fixed**: the planner finds them when their parents already exist, and the applier reports `unchanged` for the rest. A first-time plan of a packet whose parents are new still shows them as `create`, which is correct |
| 23 | A hash-valued attribute (`css_settings`) compared unequal to the stored record because the model fills in defaults, so every rerun reported `skipped_edited` | **Fixed**: `Snapshot.covers?` treats the stored hash as matching when it holds every key the packet names |
| 24 | `friendly_id_slugs` had no platform, and its unique index never enforced anything (`scope` is NULL on every row and Postgres treats NULLs as distinct). Calendars and communities also checked slugs globally, so two platforms could not share an identifier | **Fixed**: slug rows carry `platform_id` copied from their record, unique on `(platform, type, slug, locale)` through a `COALESCE` index; calendar and community no longer check slugs globally; community lookups by slug resolve inside the platform (`friendly_find_in_platform`). Not changed: the global `Person` username check, `roles` and `resource_permissions` (RBAC review) |

## What is deliberately not here

- Provenance is a dedicated table, not columns on planted records, so planted tables stay unchanged.
- No conversion of the billing planters (C6): they live on `feature/billing` and are converted there, with that branch's owner. Navigation is converted, see below.

## Tests

`spec/services/better_together/seeds/protocol/` with fixture packet `spec/fixtures/seed_packets/minimal/`.

## Provenance

Each successful plant writes, inside the same transaction, one platform-scoped `Seed` envelope row per packet (linked from the `SeedPlanting`) and one `SeedProvenance` row per planted record: packet id, packet version, record type and key, the record's class and id, the fingerprint and the flat snapshot used for edit detection. `SeedProvenance.for_record(record)` answers which packet planted a record. Reruns update rows in place, `delete` tombstones remove them, and failed or dry-run plants write nothing. `PlantingHistory` reads these rows first.

![Seed provenance model](../../diagrams/exports/png/seed_packet_provenance_model.png)

Source: [seed_packet_provenance_model.mmd](../../diagrams/source/seed_packet_provenance_model.mmd)
