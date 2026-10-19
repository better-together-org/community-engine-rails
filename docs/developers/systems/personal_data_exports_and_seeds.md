# Personal Data Exports and Seeds

This guide documents the personal-export and seed-management functionality that exists in Community Engine `0.11.0`.

## Overview

On this branch, "seed" has three related meanings:

1. a canonical `BetterTogether::Seed` record that stores a portable data envelope
2. a self-service personal export created from a person's own account data
3. a host-managed or federated import/export payload used to move structured data between systems

Relevant code paths:

- `app/models/better_together/seed.rb`
- `app/models/concerns/better_together/seedable.rb`
- `app/controllers/better_together/person_seeds_controller.rb`
- `app/controllers/better_together/seeds_controller.rb`
- `app/policies/better_together/person_seed_policy.rb`
- `app/policies/better_together/seed_policy.rb`
- `app/services/better_together/seeds/`

## Core model: `BetterTogether::Seed`

`BetterTogether::Seed` is the canonical storage model for portable exports.

Current behaviors include:

- attached YAML export via `has_one_attached :yaml_file`
- structured metadata fields such as `type`, `identifier`, `version`, `created_by`, `seeded_at`, `description`, and `origin`
- JSON payload storage in `payload`
- import helpers such as `import`, `import_or_update!`, and `plant_with_validation`
- classification helpers such as `personal_export?`, `private_linked?`, and `platform_shared?`

The model also re-attaches the YAML export after create and after content-bearing updates so the stored file tracks the current record contents.

## Security and validation

The seed system includes several guardrails in `Seed` itself:

- allowed seed file directories are limited to `config/seeds`
- YAML file size is capped at 10 MB
- YAML loading uses `YAML.safe_load_file`
- aliases are disabled
- only a small permitted class list is accepted during YAML load

These guardrails are relevant for file-backed imports and for any host app code that works directly with seed files on disk.

## Personal data export requests (`PersonDataExport`)

The GDPR-oriented export added in 0.11.0 is separate from the seed list below and runs in the background.

1. A signed-in person presses the export button on **Settings, My data** (`settings/my_data`), which posts to `POST /person_data_exports` (`PersonDataExportsController#create`). A `BetterTogether::PersonDataExport` is created with `status: pending`, `format: json` and `requested_at`; the current platform (or the host platform) is recorded.
2. An after-commit callback enqueues `GeneratePersonDataExportJob`. The job marks the export `processing`, calls `PersonDataExportService` and attaches the result as a JSON file named `person-data-export-<person id>-<date>.json`, then marks it `completed`; on any error it marks the export `failed` with the message and re-raises.
3. `GET /person_data_exports/:id` (`show`) sends the file as an attachment only when the export is `completed` and has a file; otherwise it redirects back with a "not ready" message. Only the owner can see their exports.

`PersonDataExportService` builds the file from a personal export seed (`Seeds::Builder` with the `personal_export` profile, persisted for the person) plus an account section: `exported_at`, the person's attributes (including preferences and email), memberships, agreements, blocks, reports, conversations, events, integrations and seeds.

`PersonDataExport` (`better_together_person_data_exports`): `person`, `platform`, `status` (`pending`, `processing`, `completed`, `failed`), `format` (only `json`), `requested_at`, `started_at`, `completed_at`, `error_message` and the `export_file` attachment (purged with the record). Scopes: `latest_first`, `active` (pending or processing). It is listed in `config/person_deletion_inventory.yml`; see [Person Deletion Requests and Purge Audits](person_deletion_and_purge_audit_system.md).

## Personal data exports

### Entry point

Authenticated users reach the self-service export flow through:

- `GET /my/seeds`
- `POST /my/seeds/export`
- `GET /my/seeds/:id`
- `DELETE /my/seeds/:id`

Implementation lives in `BetterTogether::PersonSeedsController`.

### Policy and scope

`PersonSeedPolicy` and `PersonSeedPolicy::Scope` restrict self-service access to personal exports that:

- belong to the current person
- are seeded from `BetterTogether::Person`
- were created by that same person

### Export flow

When a signed-in user requests an export:

1. the controller authorizes against `PersonSeedPolicy`
2. it resolves `current_user.person`
3. it enforces a one-hour cooldown using `Seed.personal_exports_for(person)`
4. it calls `person.export_as_seed(creator_id: person.id)`
5. the resulting `Seed` record appears in the person's seed list and can be viewed, downloaded, or deleted

The controller logs the export request under a GDPR-oriented log message and creates the seed synchronously. The background export described above is the file members download from My data.

See also:

- [personal data export flow diagram](../../diagrams/source/personal_data_export_seed_flow.mmd)
- [Personal Data Export Guide](../../end_users/personal_data_export_guide.md)

## `Seedable`

`BetterTogether::Seedable` is the export contract mixed into models that can emit seed envelopes.

Current capabilities include:

- `export_as_seed`
- `export_as_seed_yaml`
- `export_collection_as_seed`
- `export_collection_as_seed_yaml`

The concern also defines `plant`, which records the minimum model class and record identifier data needed for the seed envelope.

## Host-managed seed CRUD

Platform managers have a separate seed-management UI at:

- `/host/seeds`

`BetterTogether::SeedsController` provides CRUD for seed records, including JSON parsing for submitted `origin` and `payload` values.

Authorization is handled by `SeedPolicy`, which currently restricts this surface to users who can `manage_platform`.

## Federated and linked seed flows

Beyond self-service exports, the branch also contains federation-oriented services:

- `BetterTogether::Seeds::FederatedSeedBuilder`
- `BetterTogether::Seeds::FederatedSeedIngestor`
- `BetterTogether::Seeds::LinkedSeedExportService`
- `BetterTogether::Seeds::LinkedSeedIngestService`
- `BetterTogether::Seeds::PersonLinkedSeedCacheService`

`FederatedSeedBuilder` currently supports portable export envelopes for:

- `BetterTogether::Post`
- `BetterTogether::Page`
- `BetterTogether::Event`

It embeds lane and source-platform metadata into the exported origin data.

## What is not present

The current branch does not expose a dedicated JSON:API resource or MCP tool for personal data exports or host seed management. Those workflows are implemented through:

- Rails controllers and policies for self-service and host CRUD
- model/service methods for import, export, and federation

If you need the user-facing steps, see [Personal Data Export Guide](../../end_users/personal_data_export_guide.md).
