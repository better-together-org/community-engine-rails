# Search Backend Adapter System

## Overview

PR 1479 turns search backend selection into an adapterized runtime concern
instead of hard-wiring Community Engine to Elasticsearch alone.

The new design allows CE to:

- keep Elasticsearch as the default backend when it is available
- support a database fallback when a host app does not want a separate search cluster
- support a Postgres-native `pg_search` backend for hosts that want search without Elasticsearch
- resolve search backends through the shared adapter registry so host apps can override or extend search behavior

This is primarily an architecture and deployment-flexibility change rather than
a user-facing UI feature.

## Core Files

- `app/services/better_together/search.rb`
- `app/services/better_together/search/database_backend.rb`
- `app/services/better_together/search/pg_search_backend.rb`
- `app/models/better_together/page.rb`
- `app/models/better_together/post.rb`
- `lib/better_together/engine.rb`
- `better_together.gemspec`

## Runtime Architecture

The search subsystem now has three first-class backend modes:

1. `elasticsearch`
2. `database`
3. `pg_search`

`BetterTogether::Search` resolves the configured backend key, ensures the
default search adapters are registered, and instantiates the selected backend
through the shared adapter registry.

Diagrams:

- Architecture: [pr_1479_search_backend_architecture.mmd](../../diagrams/source/pr_1479_search_backend_architecture.mmd)
- Flow: [pr_1479_search_backend_flow.mmd](../../diagrams/source/pr_1479_search_backend_flow.mmd)
- Process: [pr_1479_search_backend_process.mmd](../../diagrams/source/pr_1479_search_backend_process.mmd)
- Contract normalization: [pr_1479_search_contract_normalization.mmd](../../diagrams/source/pr_1479_search_contract_normalization.mmd)
- Model onboarding: [pr_1479_searchable_model_onboarding.mmd](../../diagrams/source/pr_1479_searchable_model_onboarding.mmd)

## Backend Responsibilities

### Elasticsearch backend

- remains the default configured backend
- keeps the existing index-backed search path for hosts that already rely on it

### Database backend

- provides a no-extra-infrastructure fallback
- scores records using normalized text extracted from indexed payloads
- behaves as a no-op backend for index lifecycle methods so CE can still call
  indexing hooks safely when Elasticsearch is not in use

### PgSearch backend

- extends the database backend
- uses `pg_search_scope` when a model supports it
- falls back to database scoring when a model has not yet been upgraded with a native scope

This means CE can migrate models gradually instead of requiring an all-or-nothing
switch.

## Model Integration

Searchable models now declare their backend-neutral search contract through
`BetterTogether::Searchable`.

That concern now owns:

- Elasticsearch model wiring and index callbacks
- the shared `searchable ...` DSL for pg_search-backed model configuration
- the backend-facing query hook used by `PgSearchBackend`
- the default searchable model registry entry used by `Search::Registry`

`Page` and `Post` were migrated first, and the same contract now also covers:

- `BetterTogether::Event`
- `BetterTogether::Community`
- `BetterTogether::Joatu::Offer`
- `BetterTogether::Joatu::Request`
- `BetterTogether::Checklist`
- `BetterTogether::CallForInterest`

The shared search contract now distinguishes between:

- **native pg_search fields** backed by real table columns such as `identifier`,
  `status`, and `urgency`
- **auto-merged translated associations** from `string_translations`,
  `text_translations`, and `rich_text_translations` when a model exposes them
- **normalized plain-text document payloads** used by the database fallback path
  inside the `pg_search` adapter for models whose richest searchable content is
  assembled outside direct SQL-backed associations

Practical implications:

- translated titles/names/slugs now flow through the shared translation
  associations instead of assuming a physical `slug` column exists
- translated text fields such as `Community#description` are included for
  `pg_search` alongside translated rich text
- `Page` uses the database-compatible fallback inside the `pg_search` adapter so
  block, markdown, template, and page-rich-text content stay searchable without
  requiring unsupported nested `pg_search` association wiring

The new diagrams above separate two responsibilities:

- **contract normalization**: what the shared `Searchable` concern now does for
  every supported model
- **model onboarding**: the implementation steps a model must satisfy before it
  can reliably surface in search results across adapters

## Request Flow

At runtime the search path is:

1. read `SEARCH_BACKEND`
2. register built-in search adapters when needed
3. resolve the selected adapter entry from the registry
4. instantiate the backend
5. execute the query through the shared searchable-model contract
6. filter the returned records through policy scopes in the controller
7. return a `SearchResult` tagged with backend and status metadata

## Process Implications

The process for adding a search backend is now:

1. implement or reuse a `BetterTogether::Search::BaseBackend`
2. register it under the `:search` subsystem
3. point `SEARCH_BACKEND` at that backend key
4. onboard searchable models through `BetterTogether::Searchable`
5. optionally add model-specific pg_search configuration through the shared DSL where richer ranking is needed

## Reviewer Notes

Reviewers should treat this as:

- a new backend-selection architecture
- a shared searchable-model contract instead of model-local pg_search wiring
- a safer fallback strategy for hosts without Elasticsearch
- an incremental migration path toward Postgres-native search with policy-scope filtering at render time
