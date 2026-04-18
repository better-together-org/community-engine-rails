# Search and Filtering System

This document describes the search and filtering behavior that is actually present in the `0.11.0` release-docs worktree.

## Scope

Search and filtering currently live in four different surfaces:

1. the global `/search` page
2. the event index in `EventsController#index`
3. MCP tools for posts and events
4. the Joatu offer/request filter service

The changelog references dedicated `PostsSearchFilter` and `EventsSearchFilter` services, but those classes and their user-facing filter partials are not present in this worktree. This document stays aligned to the code that exists now.

## Global search

Main files:

- `app/controllers/better_together/search_controller.rb`
- `app/services/better_together/search.rb`
- `app/services/better_together/search/elasticsearch_backend.rb`
- `app/services/better_together/search/elasticsearch_query.rb`
- `app/services/better_together/search/registry.rb`
- `app/models/concerns/better_together/searchable.rb`

Current flow:

1. `SearchController#search` reads `params[:q]`
2. `BetterTogether::Search.backend.search(@query)` dispatches to the Elasticsearch backend
3. results are paginated in memory at 10 per page
4. `TrackSearchQueryJob` records query text, result count, and locale when a query is present

Current backend statuses exposed by the controller:

- `idle` when the query is blank
- `ok` when the backend returns results normally
- `unreachable` when Elasticsearch raises or cannot be reached
- `disabled` when the backend is not configured

## What the search registry indexes

`BetterTogether::Search::Registry::ENTRIES` currently includes only:

- `BetterTogether::Page`
- `BetterTogether::Post`

That means:

- posts participate in global search
- pages participate in global search
- events do not currently participate in global search
- the registry is also the scope used by the search rake tasks and audit tooling

## Query behavior

`BetterTogether::Search::ElasticsearchQuery` builds a `multi_match` query with:

- `type: 'best_fields'`
- `operator: 'and'`

It also requests term suggestions against the `name` field.

Search indexing is maintained through the `Searchable` concern:

- `after_commit` enqueues index jobs for persisted records
- destroy callbacks enqueue delete jobs
- the concern provides helpers for create, delete, refresh, and import operations

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

- `better_together:search:audit`
- `better_together:search:refresh`
- `better_together:search:reindex_all`
- `better_together:search:reindex_pages`
- `better_together:search:recreate_indices`

See also:

- [Search and Filter Guide](../../end_users/search_and_filter_guide.md)
- [Elasticsearch Upgrade to 8 Guide](../../platform_organizers/elasticsearch_upgrade_to_8_guide.md)
- [Posts search and filter flow](../../diagrams/source/posts_search_and_filter_flow.mmd)
- [Events search and filter flow](../../diagrams/source/events_search_and_filter_flow.mmd)
