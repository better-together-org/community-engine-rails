---
applyTo: "**/*.rb"
---
# Elasticsearch 7 Guidelines

## Indexing
- Implement `as_indexed_json` including translated/plaintext fields (strip HTML from ActionText).
- Trigger reindex jobs `after_commit` on relevant changes.

## Queries
- Prefer scoped model search methods; avoid scattering ES queries around.
- Handle pagination and highlights in service objects.

## Ops
- Self-hosted ES: monitor cluster health and disk usage.
- Use environment vars for ES URL/credentials.
