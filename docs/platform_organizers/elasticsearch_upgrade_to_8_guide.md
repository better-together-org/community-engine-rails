# Elasticsearch Upgrade to 8 Guide

**Target Audience:** Platform organizers and operators  
**Document Type:** Administrator Guide  
**Last Updated:** March 2026

## Overview

This branch already carries Elasticsearch 8 client compatibility work, but it does not ship a one-click deployment script or a large migration playbook. The operator guidance here stays focused on the surfaces that exist in the repo today:

- environment-based client configuration
- backend health and drift auditing
- index refresh and reindex tasks
- current search scope limits

## What is actually indexed on this branch

The search registry currently includes only:

- `BetterTogether::Page`
- `BetterTogether::Post`

Events are not currently part of the global Elasticsearch registry. If you are validating a release upgrade, treat pages and posts as the authoritative search coverage set for this worktree.

## Client configuration

Main code paths:

- `config/initializers/elasticsearch.rb`
- `app/services/better_together/elasticsearch_client_options.rb`

Preferred variables:

- `ELASTICSEARCH_URL`
- `ELASTICSEARCH_USERNAME`
- `ELASTICSEARCH_PASSWORD`
- `ELASTICSEARCH_CA_CERT_FILE`
- `ELASTICSEARCH_CA_FINGERPRINT`
- `ELASTICSEARCH_SSL_VERIFY`

Fallback variables still supported by the client builder:

- `ES_HOST`
- `ES_PORT`
- `ES_USERNAME`
- `ES_PASSWORD`
- `ES_CA_CERT_FILE`
- `ES_CA_FINGERPRINT`
- `ES_SSL_VERIFY`

## Why Elasticsearch 8 matters here

The client options builder explicitly supports Elasticsearch 8-style TLS configuration by allowing both a CA file and a CA fingerprint. This is the most release-relevant ES8 surface currently represented in code.

Example:

```bash
ELASTICSEARCH_URL=https://search.example.test:9200
ELASTICSEARCH_USERNAME=elastic
ELASTICSEARCH_PASSWORD=secret
ELASTICSEARCH_CA_CERT_FILE=/certs/http_ca.crt
ELASTICSEARCH_CA_FINGERPRINT=AA:BB:CC
ELASTICSEARCH_SSL_VERIFY=true
```

## Validation workflow

Run the search audit first. It gives you the cleanest branch-supported health view.

```bash
bundle exec rake better_together:search:audit
bundle exec rake better_together:search:audit FORMAT=json
```

The audit reports:

- backend availability
- whether each expected index exists
- database row count versus indexed document count
- drift between database and index

Status meanings from `AuditService`:

- `ok` / `healthy`: configured, reachable, and aligned
- `missing`: index missing for a registered model
- `drifted`: document count does not match database count
- `unreachable`: backend not responding
- `disabled`: backend not configured

## Reindex workflow

If the backend is reachable but drifted, use the supported rake tasks.

```bash
bundle exec rake better_together:search:refresh
bundle exec rake better_together:search:reindex_all
bundle exec rake better_together:search:reindex_pages
```

Use `recreate_indices` only when you intentionally want to delete and rebuild all registered indices:

```bash
bundle exec rake better_together:search:recreate_indices
```

That task prompts before destructive work.

## Application behavior during search trouble

`SearchController#search` handles backend failures gracefully:

- the page still renders
- the backend status becomes `unreachable`
- query tracking still records the attempted search with the returned result count

This is useful for release verification because users do not get a hard exception page when search is down.

## Release caveat

The changelog mentions Elasticsearch 8 validation and optional full reindex support, and both are grounded in this repo. What is **not** present here is a dedicated deployment-orchestration script for cluster upgrades, rolling restarts, or index template migrations. Keep this guide scoped to application-side validation and reindex steps.

## Related docs

- [Search and Filtering System](../developers/systems/search_and_filtering_system.md)
- [External Services Configuration](../production/external-services-to-configure.md)
- [Elasticsearch 8 reindex and validation flow](../diagrams/source/elasticsearch_8_reindex_and_validation_flow.mmd)
