---
applyTo: "**/*.rb"
---
# Search Guidelines

## Backends
- Default is Postgres-native `pg_search` (`SEARCH_BACKEND=pg_search`); `database` is the no-extension fallback.
- Elasticsearch is not in core. It lives in the optional `better_together-elasticsearch` extension gem, which registers an `elasticsearch` backend in the `:search` adapter group.

## Models
- Include `BetterTogether::Searchable` and declare `searchable pg_search: { ... }`; a model without a declaration drops out of search.
- Use real columns in `against:`; translated fields are merged automatically from the translation associations.
- Keep `as_indexed_json` as lean plain text (strip HTML from rich text). It feeds the database fallback and the Elasticsearch gem.

## Queries
- Go through `BetterTogether::Search.backend`; do not scatter backend-specific queries.
- Filter results through policy scopes before rendering; do not expose backend term suggestions.

## Ops
- `rake better_together:search:audit` reports backend status; reindex tasks only act on index-backed backends.
