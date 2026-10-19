# Search and Filtering System

This document describes the search and filtering behavior present in 0.11.0.

## Scope

Search and filtering currently live in four different surfaces:

1. the global `/search` page
2. the event index in `EventsController#index`
3. MCP tools for posts and events
4. the Joatu offer/request filter service

The changelog references dedicated `PostsSearchFilter` and `EventsSearchFilter` services, but those classes and their user-facing filter partials are not present in the codebase. This document stays aligned to the code that exists.

## Global search

Main files:

- `app/controllers/better_together/search_controller.rb`
- `app/services/better_together/search.rb`
- `app/services/better_together/search/pg_search_backend.rb`
- `app/services/better_together/search/database_backend.rb`
- `app/services/better_together/search/registry.rb`
- `app/models/concerns/better_together/searchable.rb`

Current flow:

1. `SearchController#search` reads `params[:q]`
2. `BetterTogether::Search.backend.search(@query)` dispatches to the configured backend (`SEARCH_BACKEND`, default `pg_search`)
3. results are paginated in memory at 10 per page
4. `TrackSearchQueryJob` records query text, result count, and locale when a query is present

Current backend statuses exposed by the controller:

- `idle` when the query is blank
- `ok` when the backend returns results normally
- `unreachable` when the backend raises or cannot be reached
- `disabled` when the backend is not configured (reported by the audit service)

## What the search registry indexes

`BetterTogether::Search::Registry.entries` is built from every model that includes `BetterTogether::Searchable`. In core that is:

- `BetterTogether::Page`
- `BetterTogether::Post`
- `BetterTogether::Event`
- `BetterTogether::Community`
- `BetterTogether::Joatu::Offer`
- `BetterTogether::Joatu::Request`
- `BetterTogether::Checklist`
- `BetterTogether::CallForInterest`

Models opt out of the global `/search` page with `searchable global_search: false`. The registry is also the scope used by the search rake tasks and audit tooling. Host models appear in search only if they include `Searchable` and declare a backend (`searchable pg_search: { ... }`).

## Query behavior

`PgSearchBackend` runs each registry entry's `pg_search` scope when the model declares one, selects `pg_search_rank` as the score (`with_pg_search_rank`), and limits each model to 50 matches. Models without a scope are scored by `DatabaseBackend` from their normalized plain-text payload (`as_indexed_json`). Results from every model are merged, then filtered through the policy scopes in `SearchController` before pagination. Backend term suggestions are not shown because they are not privacy-aware.

With the optional `better_together-elasticsearch` extension gem and `SEARCH_BACKEND=elasticsearch`, queries go to its Elasticsearch backend instead; the controller, registry and result contract are the same. See the gem's README for its query, indexing and reindex behaviour.

## Event discovery and filtering

Main files:

- `app/controllers/better_together/events_controller.rb`
- `app/models/better_together/event.rb`
- `app/policies/better_together/event_policy.rb`
- `app/tools/better_together/mcp/list_events_tool.rb`

The web index does not currently apply a dedicated search form. Instead, it:

- loads the policy-scoped event relation
- includes categories
- derives `@draft_events`, `@upcoming_events`, `@ongoing_events`, and `@past_events`

The event model supplies the timing scopes:

- `draft`
- `scheduled`
- `upcoming`
- `ongoing`
- `past`

Visibility is handled by `EventPolicy::Scope`, which allows extra access for creators, platform stewards, event hosts, attendees, and valid invitation tokens.

## Post filtering outside global search

There is no dedicated posts index filter controller on this branch.

The closest implemented branch surface is the MCP `SearchPostsTool`, which:

- starts from `policy_scope(BetterTogether::Post)`
- limits results to published, accessible posts
- respects block relationships through `PostPolicy::Scope`
- searches translated post content and titles
- orders by `published_at DESC`

## Event filtering outside the web index

`ListEventsTool` exposes the most explicit event filter API on this branch.

Supported arguments:

- `scope`: `upcoming`, `past`, `ongoing`, `draft`, `scheduled`
- `privacy_filter`: `public` or `private`
- `limit`

Results are ordered by `starts_at ASC` and serialized as JSON for MCP clients.

## Joatu filtering is separate

`app/services/better_together/joatu/search_filter.rb` powers offer/request filtering, not posts or events. It supports category filters, text search, open/closed status, order-by, and pagination for Joatu resources only.

## Operational hooks

Search maintenance lives in `lib/tasks/search.rake`:

- `better_together:search:audit` reports backend status and database-to-index parity
- `better_together:search:reindex_all`, `reindex_pages`, `refresh` and `recreate_indices` call the active backend's index lifecycle methods. They are no-ops for `pg_search` and `database`, which query live tables, and do real work only with an index-backed backend such as the Elasticsearch extension gem.

See also:

- [Search Backend Adapter System](search_backend_adapter_system.md)
- [Search and Filter Guide](../../end_users/search_and_filter_guide.md)
- [Posts search and filter flow](../../diagrams/source/posts_search_and_filter_flow.mmd)
- [Events search and filter flow](../../diagrams/source/events_search_and_filter_flow.mmd)
- [`better_together-elasticsearch`](https://github.com/better-together-org/better_together-elasticsearch) (optional)
