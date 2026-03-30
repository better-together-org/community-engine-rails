# Metrics & Reports System

This guide explains how page views, link clicks, shares, and downloads are tracked, and how reports are generated and exported.

## Tracking Overview
- Frontend (Stimulus): `metrics_controller.js` attaches to the page root, tracks page views on load and link clicks on click.
  - Page view POST payload: `viewable_type`, `viewable_id`, `locale` → creates `Metrics::PageView`.
  - Link click POST payload: `url`, `page_url`, `internal` → creates `Metrics::LinkClick`.
- Shares (Stimulus): `share_controller.js` constructs share URLs and posts tracking events to record platform, url, and shareable ids.
- Search queries: tracked in two ways:
  - Server‑side in `SearchController#search` after Elasticsearch returns (records `query`, `results_count`, `locale`).
  - API endpoint `/:locale/bt/metrics/search_queries` (POST) via `Metrics::SearchQueriesController#create` for client‑side tracking.
  - Host platforms can disable search-query analytics entirely or switch to hashed capture so repeated terms can still be counted without storing raw query text.
- Downloads: when a report file is downloaded, `TrackDownloadJob` records a `Metrics::Download` (filename, content_type, byte_size, locale).

## Data Models
- `Metrics::PageView`
  - Belongs to `pageable` (polymorphic), stores `viewed_at`, `locale`, `page_url`.
  - Sanitizes query params to avoid sensitive keys in persisted `page_url`.
  - Derives `page_url` from `pageable.url` or `polymorphic_url`.
- `Metrics::LinkClick`
  - Stores `url`, `page_url`, `internal` (boolean), `clicked_at`, `locale`.
- `Metrics::Share`
  - Stores `platform` (facebook, linkedin, etc.), `url`, `shareable_type/id`, `shared_at`, `locale`.
- `Metrics::Download`
  - Stores `filename`, `content_type`, `byte_size`, `downloaded_at`, `locale`.
- `Metrics::SearchQuery`
  - Stores `query`, `searched_at`, `locale`.
  - Created by `Metrics::TrackSearchQueryJob` either from `SearchController#search` or the `/metrics/search_queries` endpoint.
  - When a platform sets `search_query_analytics_mode` to `hashed`, stored values are SHA-256 digests prefixed with `sha256:`.

## Reports
- `Metrics::LinkClickReport`
  - Filters: `from_date`, `to_date`, `filter_internal`.
  - Output: aggregated by URL with locale breakdowns, friendly names (per locale), and originating `page_url`.
  - Sorting: optional `sort_by_total_clicks`.
  - Export: CSV attached to `report_file` (Active Storage); filename includes filters and timestamp.
- `Metrics::PageViewReport`
  - Filters: `from_date`, `to_date`, `filter_pageable_type`.
  - Output: totals per `pageable_id` with locale breakdowns and friendly titles per locale; includes `page_url`.
  - Sorting: optional `sort_by_total_views`.
  - Export: CSV attached to `report_file` (Active Storage); filename includes filters and timestamp.

## Controllers & Routes
- Host Dashboard → Metrics → Link Click Reports / Page View Reports:
  - `index`: lists past reports (latest first).
  - `new`: filter form (with select options per model).
  - `create`: builds and generates report, then returns to index (Turbo Stream support).
  - `download`: streams attached CSV; logs a `Metrics::Download` via `TrackDownloadJob`.
- Routes: `/:locale/bt/host/metrics/{link_click_reports|page_view_reports}`.
  - Metrics API endpoints (public, behind locale/bt scope): `/:locale/bt/metrics/{page_views|link_clicks|shares|search_queries}` (POST only).

## Charts (Admin)
- `metrics_charts_controller.js` renders bar/line charts for page views, link clicks, downloads, shares, and shares per URL per platform using Chart.js.
- Data is injected via `data-chart-data` on canvas elements.

## Notes
- Privacy‑first:
  - We record what happened, not who did it. No user identifiers are stored in metrics events.
  - Page view URLs strip query parameters and are sanitized to remove sensitive keys; persisted `page_url` is the path only.
  - Search query tracking can be disabled per host platform, or reduced to hashed values so raw search terms are not retained.
  - Platform managers may add third‑party tools (e.g., GA, Sentry) per their own privacy policy and consent practices.
- Locale: all metrics record `locale` for reporting.
- Performance: reports aggregate via grouped database queries and only touch filtered subsets.
- Storage: exported CSVs are attached via Active Storage and purged on report destroy.

## Data Deletion & Retention
Use the built-in retention task to purge stale raw metrics and generated report exports in line with your host privacy policy.

Default windows:
- raw metrics: 180 days
- generated report exports: 90 days

Dry run:

```bash
bundle exec rake better_together:metrics:retention DRY_RUN=true
```

Override the windows:

```bash
bundle exec rake better_together:metrics:retention RAW_METRICS_DAYS=120 REPORT_DAYS=30
```

The task:
- deletes old raw metrics in batches to avoid long-running transactions
- destroys old report records so their attached export files are purged too
- prints a JSON summary of eligible and deleted rows for each metrics/report type

Tips:
- schedule the task during low-traffic maintenance windows
- use `DRY_RUN=true` before changing windows in production
- announce retention in your privacy policy and honor deletion requests
