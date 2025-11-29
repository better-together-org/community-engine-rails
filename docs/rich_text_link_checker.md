# RichText Link Checker

This document describes the pipeline that identifies links in ActionText rich content and checks them.

Process overview:

1. Identify: `BetterTogether::Metrics::RichTextLinkIdentifier` scans `ActionText::RichText` records and extracts links.
2. Persist: For each link, create or find a `BetterTogether::Content::Link` and a `BetterTogether::Metrics::RichTextLink` join record.
3. Queue: `rich_text:links:check` Rake task enqueues two queue jobs: internal and external checker queues.
4. Distribute: `RichTextLinkCheckerQueueJob` groups links by host and schedules child check jobs over a time window to avoid bursts.
5. Check: Child jobs (`InternalLinkCheckerJob` and `ExternalLinkCheckerJob`) perform HTTP HEAD requests and update Link metadata.

Documentation files:
- diagrams/source/rich_text_link_checker_flow.mmd (Mermaid source)
- diagrams/exports/png/rich_text_link_checker_flow.png (export placeholder)

Running locally:

Use Docker wrapper for commands that need DB access (see repo README):

```
bin/dc-run rails runner "BetterTogether::Metrics::RichTextLinkIdentifier.call"
bin/dc-run rake better_together:qa:rich_text:links:identify
bin/dc-run rake better_together:qa:rich_text:links:check
```

Notes:
- External HTTP checks are rate-limited by the queueing logic. Configure behavior in the queue job if needed.
- Tests use WebMock to stub external HTTP calls.
