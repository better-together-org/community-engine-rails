# Search Backend Adapter System

## Overview

Search backend selection is an adapterized runtime concern. Core ships two
backends and no external search service; additional backends register through
the shared adapter registry.

Since 0.11.0 CE:

- uses the Postgres-native `pg_search` backend by default (`SEARCH_BACKEND` defaults to `pg_search`)
- keeps a `database` backend as the no-extension fallback
- no longer depends on `elasticsearch-model` or `elasticsearch-rails`; Elasticsearch lives in the optional
  [`better_together-elasticsearch`](https://github.com/better-together-org/better_together-elasticsearch) extension gem, which
  registers an `elasticsearch` backend with the same registry
- resolves search backends through the shared adapter registry so host apps and extension gems can override or extend search behavior

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

Core has two first-class backend modes:

1. `pg_search` (default)
2. `database`

Extension gems add more. With `better_together-elasticsearch` installed, an `elasticsearch` key is registered as well.
If `SEARCH_BACKEND` names a key with no registered adapter, `BetterTogether::Search` falls back to `pg_search`, then `database`.

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

### Elasticsearch (extension gem)

- not part of core; install `better_together-elasticsearch` and set `SEARCH_BACKEND=elasticsearch`
- the gem owns the client configuration, indexing callbacks and jobs, and the model document concerns
  (see its README for `register_model_document`)
- core only exposes the generic search backend registry and the searchable-model registry the gem plugs into

### Database backend

- provides a no-extra-infrastructure fallback
- scores records using normalized text extracted from indexed payloads
- behaves as a no-op backend for index lifecycle methods so CE can still call
  indexing hooks safely when no index-backed backend is in use

### PgSearch backend

- extends the database backend
- uses `pg_search_scope` when a model supports it
- falls back to database scoring when a model has not yet been upgraded with a native scope

This means CE can migrate models gradually instead of requiring an all-or-nothing
switch.

## Model Integration

Searchable models declare their backend-neutral search contract through
`BetterTogether::Searchable`.

That concern now owns:

- the shared `searchable ...` DSL for pg_search-backed model configuration
- the backend-facing query hook used by `PgSearchBackend`
- the default searchable model registry entry used by `Search::Registry`

The registry (`BetterTogether::Search::Registry`) currently contains these models:

- `BetterTogether::Page`
- `BetterTogether::Post`
- `BetterTogether::Event`
- `BetterTogether::Community`
- `BetterTogether::Joatu::Offer`
- `BetterTogether::Joatu::Request`
- `BetterTogether::Checklist`
- `BetterTogether::CallForInterest`

A host model that includes `Searchable` without declaring a backend (`searchable pg_search: { ... }` or the fallback
payload) silently drops out of search. Host models migrating from Elasticsearch must replace
the Elasticsearch `settings index: default_elasticsearch_index` and `mappings` declarations (`default_elasticsearch_index` no longer exists in core). `as_indexed_json` stays as the plain-text payload used by the database fallback. See the
[host upgrade guide](../../releases/0.11.0_host_upgrade_guide.md).

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
- a safe default for hosts that do not run a separate search service
- an incremental migration path toward Postgres-native search with policy-scope filtering at render time
