# Elasticsearch in Community Engine 0.11.0

**Target Audience:** Platform organizers and operators  
**Document Type:** Administrator Guide  
**Last Updated:** October 2026

## What changed

Elasticsearch is no longer part of the Community Engine core gem. In 0.10.x the core gem depended on `elasticsearch-model` and `elasticsearch-rails` 7 and used Elasticsearch as the search backend. From 0.11.0:

- core search runs on Postgres (`SEARCH_BACKEND=pg_search`, the default) and needs no search service
- Elasticsearch support lives in the optional [`better_together-elasticsearch`](https://github.com/better-together-org/better_together-elasticsearch) extension gem, which depends on the Elasticsearch 8 client libraries (`elasticsearch-model` and `elasticsearch-rails` `~> 8`)
- core keeps the generic search backend registry and searchable-model registry that the gem plugs into

This page used to document the Elasticsearch 8 client work in core. That code and its configuration (`config/initializers/elasticsearch.rb`, `ElasticsearchClientOptions`) are gone from core and are owned by the gem.

## If you do not need Elasticsearch

Do nothing beyond the normal upgrade. Remove any Elasticsearch service from your deployment once nothing else uses it, and see the [host upgrade guide](../releases/0.11.0_host_upgrade_guide.md) for host models that still declare Elasticsearch index settings.

## If you want to keep using Elasticsearch

1. Add the gem to the host app Gemfile and bundle:

   ```ruby
   gem 'better_together-elasticsearch', github: 'better-together-org/better_together-elasticsearch', branch: 'main'
   ```

2. Set `SEARCH_BACKEND=elasticsearch` and the connection settings described in the gem README.
3. Register a document concern for each host model that should be indexed (see the gem README for `register_model_document`).
4. Build the indexes and check health:

   ```bash
   bin/rails better_together:search:reindex_all
   bin/rails better_together:search:audit
   ```

   `audit` reports backend status and database-to-index drift; the reindex tasks call the active backend's index lifecycle methods.

The gem has no tagged release yet, so pin it by branch or commit and review its changes before upgrading.

## Related

- [Search Backend Adapter System](../developers/systems/search_backend_adapter_system.md)
- [Search and Filtering System](../developers/systems/search_and_filtering_system.md)
- [Host upgrade guide](../releases/0.11.0_host_upgrade_guide.md)
