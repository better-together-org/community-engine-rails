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
  - Search query tracking stores the query string, count of results, timestamp, and locale.
  - Platform managers may add third‑party tools (e.g., GA, Sentry) per their own privacy policy and consent practices.
- Locale: all metrics record `locale` for reporting.
- Performance: reports aggregate via grouped database queries and only touch filtered subsets.
- Storage: exported CSVs are attached via Active Storage and purged on report destroy.

## Data Deletion & Retention (Examples)
These examples illustrate how a host can manage retention and deletion in line with their policy. Adjust windows to your needs and run in maintenance windows.

Rails console snippets:

```ruby
# Purge report exports older than 90 days
BetterTogether::Metrics::LinkClickReport.where('created_at < ?', 90.days.ago).find_each(&:destroy)
BetterTogether::Metrics::PageViewReport.where('created_at < ?', 90.days.ago).find_each(&:destroy)

# Delete raw metrics older than 180 days (batch as needed)
BetterTogether::Metrics::PageView.where('viewed_at < ?', 180.days.ago).in_batches.delete_all
BetterTogether::Metrics::LinkClick.where('clicked_at < ?', 180.days.ago).in_batches.delete_all
BetterTogether::Metrics::Share.where('shared_at < ?', 180.days.ago).in_batches.delete_all
BetterTogether::Metrics::Download.where('downloaded_at < ?', 180.days.ago).in_batches.delete_all
BetterTogether::Metrics::SearchQuery.where('searched_at < ?', 180.days.ago).in_batches.delete_all
```

Tips:
- Use `in_batches` to avoid long‑running transactions.
- Consider wrapping deletions in a Rake task and scheduling via cron.
- Announce retention in your privacy policy and honor deletion requests.
