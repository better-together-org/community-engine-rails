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

`BetterTogether::Page` and `BetterTogether::Post` now include `PgSearch::Model`
and expose `pg_search_scope :pg_search_query`.

The initial scope covers:

- slugs and identifiers
- translated string content
- translated rich text content

## Request Flow

At runtime the search path is:

1. read `SEARCH_BACKEND`
2. register built-in search adapters when needed
3. resolve the selected adapter entry from the registry
4. instantiate the backend
5. execute the query through that backend
6. return a `SearchResult` tagged with backend and status metadata

## Process Implications

The process for adding a search backend is now:

1. implement or reuse a `BetterTogether::Search::BaseBackend`
2. register it under the `:search` subsystem
3. point `SEARCH_BACKEND` at that backend key
4. optionally add model-native scopes where richer ranking is needed

## Reviewer Notes

Reviewers should treat this as:

- a new backend-selection architecture
- a safer fallback strategy for hosts without Elasticsearch
- an incremental migration path toward Postgres-native search
