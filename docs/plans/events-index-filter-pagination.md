# Plan: Events Index — Search, Filter Sidebar, Pagination

**v0.12.0 Release** | **Tracking issue:** better-together-org/community-engine-rails#1410

**Related plans:**
- [Posts index search/filter/pagination](posts-index-filter-pagination.md) — PR #1409 — **pattern source**
- [Federation authorship opt-in](federation-authorship-opt-in.md) — PR #1408

**Reference:** [v0.12.0 Stakeholder-Centered Acceptance Criteria Framework](../implementation/STAKEHOLDER_AC_IMPLEMENTATION_GUIDE.md)

---

## Background

The events index currently renders events in four hardcoded partitions (`@draft_events`, `@upcoming_events`, `@past_events`, etc.) with no text search, no flexible filtering, and no pagination. As platforms host more events (federated + local), browsing becomes overwhelming and inflexible. The posts index filter pattern (PR #1409) provides the correct template: a single unified `@events` relation with search sidebar, category filter, status filter, flexible date-based order-by, and Kaminari pagination.

Events should adopt this pattern, replacing the four-partition model with a single filterable collection.

---

## Goals

1. Replace four hardcoded `@*_events` partition variables with single `@events` relation filtered via `EventsSearchFilter`.
2. Add text search (title + description ILIKE), category filter, status filter (draft/confirmed/cancelled).
3. Add flexible order-by: `soonest` (earliest start), `latest` (furthest start), `newest` (most recent creation), `oldest` (earliest creation).
4. Add Kaminari pagination with configurable per-page (10/20/50).
5. Default view: upcoming events (start_at ≥ now), soonest-first, 20 per page.
6. Reuse `BetterTogether::ContentSearchFilter` base class from PR #1409 for consistency.

---

## v0.12.0 Stakeholder Outcomes

This feature serves three distinct outcomes in the v0.12.0 framework:

| Stakeholder | Need | Success Metric |
|------------|------|-----------------|
| **Community Members** | "I can find events about topics I care about, coming soon" | Text search + category filter + soonest-first default |
| **Event Organizers** | "I can see my events in one view (drafts, confirmed, past)" | Status filter works; can toggle visibility; defaults to drafts + upcoming |
| **Platform Managers** | "The calendar is usable when we have 100+ events" | Pagination prevents bloat; soonest default limits clutter |

Implementation follows the **test-first cadence**: pending RSpec specs → implement → validate each week, in parallel with Posts (Week 1–3).

---

## Out of Scope

- Elasticsearch integration (v0.12.0 standardizes on pgsearch/SQL ILIKE across all platforms).
- Calendar view (grid layout by date); possible v0.12.1 feature.
- Time zone conversions in "soonest" order (use platform default; noted for v0.12.1 enhancement).
- Saved search / bookmarked filters (possible v0.12.1 enhancement).

---

## Acceptance Criteria

### Controller (`EventsController#index`)

- [x] `EventsController#index` applies an `EventsSearchFilter` to the policy-scoped collection before rendering.
- [x] Accepted params: `q` (text search), `category_ids[]`, `status` (draft/confirmed/cancelled/all), `order_by` (soonest/latest/newest/oldest), `per_page` (10/20/50), `page`.
- [x] Params are passed through to the view for form state persistence (selected filters remain checked/filled on page reload).
- [x] Default: upcoming events (start_at ≥ now), soonest-first, 20 per page, status=confirmed+upcoming (exclude past + draft unless explicitly selected).

### Search / filter service (`EventsSearchFilter`)

- [x] Implemented as a service object under `BetterTogether::`, inheriting from `BetterTogether::ContentSearchFilter` (from PR #1409).
- [x] `search_text` step: ILIKE join on Mobility `mobility_string_translations` (title key) and ActionText `action_text_rich_texts` (description name), with locale fallback (inherited from base).
- [x] `filter_by_categories` step: joins `better_together_categorizations` and `better_together_categories` when `params[:category_ids]` is present (inherited from base).
- [x] `filter_by_status` step: filters by `status` enum (draft/confirmed/cancelled) or union of statuses.
- [x] `filter_by_date_range` step: default scope filters to `start_at >= Time.current` (upcoming); optional `past` flag for historical events.
- [x] `order_by` step: flexible date-based ordering:
  - `soonest` (default): `start_at asc` — earliest events first
  - `latest`: `start_at desc` — furthest events first
  - `newest`: `created_at desc` — most recently created events first
  - `oldest`: `created_at asc` — earliest created events first
- [x] `paginate` step: `.page(params[:page]).per(per_page)` via Kaminari (inherited from base).
- [x] Returns a Kaminari-decorated relation.

### View

- [x] `app/views/better_together/events/index.html.erb` updated to:
  - Render `_list_form` sidebar partial (GET form, consistent with Posts/Joatu style).
  - Render paginated event cards / list items (replace four hardcoded `@*_events` partials).
  - Show `paginate @events` Kaminari navigation.
  - Show result count: "X events" (with active filter indicator if filters applied).
- [x] `app/views/better_together/events/_list_form.html.erb` new partial:
  - Text search input (`q`).
  - Category checkboxes (dynamically loaded from `BetterTogether::Category` scoped to events).
  - Status select (All / Draft / Confirmed / Cancelled).
  - Order-by select (Soonest / Latest / Newest / Oldest).
  - Per-page select (10 / 20 / 50).
  - Submit button; clear-filters link.
- [x] Filter sidebar is collapsible on mobile (consistent with Posts + Joatu implementation).

### i18n

- [x] All new UI strings added to `config/locales/en.yml` under `better_together.events.index.*`.

---

## Test-First Implementation (v0.12.0 Framework)

All specs are **pending** until implementation week; run with:
```bash
rspec spec/acceptance_criteria/events_index_spec.rb --tag acceptance_criteria --pending
```

### Required Test Suite: `spec/acceptance_criteria/events_index_spec.rb`

**Model Layer (Week 1 — Service foundation; can run in parallel with Posts Week 1)**
- [x] `EventsSearchFilter.call(relation:, params:)` returns Kaminari-decorated relation
- [x] `q: "community"` applies ILIKE to Mobility title + ActionText description (both locales)
- [x] `category_ids: [id]` joins categorizations and returns only tagged events
- [x] `status: "draft"` filters by events.status enum
- [x] `status: ["draft", "confirmed"]` supports status union (multiple statuses)
- [x] `order_by: "latest"` orders `start_at desc` (furthest events first)
- [x] `order_by: "newest"` orders `created_at desc` (most recently created)
- [x] `order_by: "soonest"` (default) orders `start_at asc` (earliest start first)
- [x] Empty params returns upcoming events only (start_at ≥ now), soonest-first
- [x] No N+1 queries on empty params (pre-load associations correctly)

**Request Layer (Week 2 — Controller + authorization)**
- [x] `GET /en/events` with no params returns 200, upcoming events, soonest-first, 20 per page
- [x] `?q=yoga` filters results by title/description, params persist in view
- [x] `?category_ids[]=1&category_ids[]=2` multi-select works
- [x] `?status=draft` shows only drafts
- [x] `?status[]=draft&status[]=confirmed` shows drafts + confirmed (union)
- [x] `?order_by=latest` orders furthest-first
- [x] `?page=2&per_page=10` paginates correctly
- [x] Authorization: respects policy scope (user sees only permitted events; organizer sees own drafts)

**Feature Layer (Week 3 — UX + pagination)**
- [x] Visit `/en/events`, see filter sidebar with all controls
- [x] Type in search box, submit form, results filter by title + description
- [x] Check category checkboxes (multi-select), results update
- [x] Select status dropdown, results filter
- [x] Select order-by, results re-sort immediately (soonest/latest/newest/oldest all work)
- [x] Select per-page, page reloads with new window size
- [x] Pagination links present and navigate correctly
- [x] "Clear filters" link resets to default state (upcoming, soonest, 20 per page)
- [x] Sidebar collapses on mobile (≤768px)

---

## Stakeholders

| Name | Role |
|------|------|
| Rob Polowick | Product lead |
| Community Organizers | Create + manage events; need to see drafts + confirmed in one view |
| Platform managers | Observe events index in production; need usable browse UX at scale |
| Community members | Discover and RSVP to upcoming events |

---

## Implementation Notes

### As-built notes (2026-07-11)

**Status column decision:** `better_together_events` previously had **no** `status`
column — "draft" was derived from `starts_at IS NULL` (scopes `draft`/`scheduled`/
`upcoming`/`ongoing`/`past`). This plan and the acceptance spec assume a real
draft/confirmed/cancelled state, so migration `20260711000000_add_status_to_better_together_events`
adds a string `status` column (default `confirmed`, `NOT NULL`, indexed) and backfills
`starts_at IS NULL → 'draft'`. The enum is declared with `prefix: :status`
(`status_draft?`, `Event.status_confirmed`, ...) so it does not collide with the
timing-derived `Event.draft` scope and `#draft?` predicate, which are load-bearing
elsewhere (MCP list tool, JSONAPI resource, people/communities controllers, RSVP
view/validation) and remain unchanged. Status is orthogonal to timing: an event can
be confirmed AND past, or cancelled AND upcoming.

**Draft visibility:** `EventPolicy::Scope` now excludes `status = 'draft'` events from
the base visibility query; creators, hosts, attendees, invitees, and platform event
managers still see them. New events default to `confirmed`, so existing creation flows
keep publishing immediately; drafting is an explicit choice (`status` is mass-assignable
via `Event.permitted_attributes`, though the event form does not yet expose it).

**Deviations from the original plan text:**
- `filter_by_status` and `filter_by_date_range` are implemented inside the
  `filter_by_resource_specific_status` hook that `ContentSearchFilter` actually
  exposes (the base class has no separate status/date hooks).
- The default view applies `starts_at >= Time.current` literally (per AC10/AC12):
  **ongoing** events (already started, not yet ended) drop out of the default view
  the moment they start, and unscheduled events (NULL `starts_at`) never appear in
  the date-windowed views. A `past=1` param (checkbox in the sidebar) flips the
  window to historical events, replacing the old "Recent events" section.
- The default view does **not** restrict status (a cancelled upcoming event is
  listed with a "Cancelled" badge); others' drafts are hidden by the policy scope,
  not by a default status filter.
- `ContentSearchFilter#filter_by_categories` (shared with Posts) now predicates on
  `categorizations.category_id` instead of joining the categories table — a where
  hash keyed by the categories table name forced the events policy scope's
  polymorphic category preloads into eager loading (`EagerLoadPolymorphicError`).
- Spec corrections at activation time: Event translates `:name` (not `:title`),
  column is `starts_at` (not `start_at`), events have `creator:` (not `organizer:`),
  categorizations take `categorizable:`. AC15's draft belongs to the signed-in
  person, since others' drafts are correctly hidden by the policy scope.

**Search Strategy:** v0.12.0 standardizes on **pgsearch (PostgreSQL ILIKE)** across all platforms. No Elasticsearch detection or fallback; all deployments use SQL joins + ILIKE.

**Reuse from Posts (PR #1409):**
- Inherit from `BetterTogether::ContentSearchFilter` base class (created Week 1 of Posts implementation)
- Base provides: search_text (Mobility + ActionText joins), filter_by_categories, paginate steps
- Events override: `#default_order_by`, `#filter_by_status`, `#filter_by_date_range` methods

- **Mobility joins:** Text search joins `mobility_string_translations` (Mobility title key)
  and `action_text_rich_texts` (ActionText description name), with locale scoping. Inherited from base.

- **Category filter:** Events are `Categorizable`; join `better_together_categorizations`
  and `better_together_categories`. Multi-select on category IDs. Inherited from base.

- **Status filter:** Use the `status` enum directly (draft/confirmed/cancelled).
  Support both single value and array for OR union (`status: ["draft", "confirmed"]`).
  Respect policy scope — don't expose filtering UI for states user can't see.

- **Date-based ordering:** Four distinct strategies:
  - `soonest`: `start_at asc` (earliest start)
  - `latest`: `start_at desc` (furthest start)
  - `newest`: `created_at desc` (most recent creation)
  - `oldest`: `created_at asc` (earliest creation)
  
  Note for v0.12.1: Add timezone awareness to "soonest" ordering if platform uses multiple time zones.

- **Default scope:** Filter to upcoming events (`start_at >= Time.current`) by default.
  Organizers see their own drafts regardless. Members see confirmed upcoming only.

- **Kaminari:** Already a dependency; use `.page(params[:page]).per(per_page)` (inherited from base).

- **GET form:** Filter form uses GET (not POST) so filters are bookmarkable (`/events?status=draft&order_by=newest&page=1`).

**Integration points:**
- `FriendlyResourceController#resource_collection` is the right integration point (same as Posts).
- Override in `EventsController` to apply `EventsSearchFilter` before returning.

---

## Implementation Sequence

```
Week 1: Model + Service Layer (parallel with Posts Week 1)
  spec/acceptance_criteria/events_index_spec.rb      (new; model specs — pending)
  app/services/better_together/events_search_filter.rb   (new; inherits from ContentSearchFilter)
  [ContentSearchFilter base created in Posts Week 1, reused here]

Week 2: Request + Controller Layer (parallel with Posts Week 2)
  spec/acceptance_criteria/events_index_spec.rb      (add request specs — pending)
  app/controllers/better_together/events_controller.rb   (override resource_collection)

Week 3: View + i18n (parallel with Posts Week 3)
  spec/acceptance_criteria/events_index_spec.rb      (add feature specs — pending)
  app/views/better_together/events/index.html.erb    (update; remove four @*_events partials, add @events)
  app/views/better_together/events/_list_form.html.erb   (new)
  config/locales/en.yml                              (add events.index.* keys)
```

**Dependency on Posts:** Events Week 1 depends on `ContentSearchFilter` base class created in Posts Week 1.
Both can proceed in parallel after the base is available.

---

## Migration from Four-Partition Model

**Current state:**
```ruby
@draft_events = current_platform.events.draft.order(:start_at)
@upcoming_events = current_platform.events.confirmed.upcoming.order(:start_at)
@past_events = current_platform.events.confirmed.past.order(:start_at)
@cancelled_events = current_platform.events.cancelled.order(:start_at)
```

**New state:**
```ruby
@events = EventsSearchFilter.call(
  relation: current_platform.events,
  params: filter_params
)
# Single paginated relation, filtered by q, category_ids, status, order_by
```

**View changes:**
- Remove: `<%= render @draft_events %>`, `<%= render @upcoming_events %>`, etc.
- Add: `<%= render @events %>` (single unified list)
- Add: `<%= paginate @events %>` (pagination)
- Add: `<%= render "list_form", params: filter_params %>` (filter sidebar)

---

## Success Criteria (v0.12.0)

Implementation is **complete** when:

- [x] All 28 specs in `events_index_spec.rb` pass ✓
- [x] `EventsController#index` applies `EventsSearchFilter` before render ✓
- [x] Four partition variables (`@*_events`) removed; replaced with single `@events` ✓
- [x] Filter sidebar renders; all controls functional ✓
- [x] Pagination works; default 20/page, soonest-first ✓
- [x] Authorization respected (policy scope + status visibility) ✓
- [x] Default view shows upcoming events only (excludes past + draft unless explicitly selected) ✓
- [x] i18n keys added under `better_together.events.index.*` ✓
- [x] Mobile sidebar collapses ≤768px ✓
- [x] Posts mirror (PR #1409) also complete, both share `ContentSearchFilter` base ✓

---

## Code Path Reference

**Files to create/modify:**

```
Week 1 (Service Foundation; parallel with Posts Week 1)
  spec/acceptance_criteria/events_index_spec.rb       (new; model layer pending)
  app/services/better_together/events_search_filter.rb    (new; inherits ContentSearchFilter)

Week 2 (Controller + Auth; parallel with Posts Week 2)
  spec/acceptance_criteria/events_index_spec.rb       (extend with request specs)
  app/controllers/better_together/events_controller.rb    (override resource_collection)

Week 3 (Views + i18n; parallel with Posts Week 3)
  spec/acceptance_criteria/events_index_spec.rb       (extend with feature specs)
  app/views/better_together/events/index.html.erb     (update; remove @*_events partials)
  app/views/better_together/events/_list_form.html.erb    (new)
  config/locales/en.yml                               (add events.index.*)
```

**Reference implementations:**
- `app/services/better_together/posts_search_filter.rb` (PR #1409) — Inherits from this base
- `app/services/better_together/content_search_filter.rb` (PR #1409, Week 1) — Base class
- `app/services/joatu/search_filter.rb` — Mobility join pattern
- `app/views/joatu/offers/_list_form.html.erb` — Filter sidebar UX pattern

---

## v0.12.1 Enhancements (Deferred)

- Calendar/grid view by date (complex rendering; defer post-filtering MVP)
- Timezone-aware "soonest" ordering across multi-timezone deployments
- Saved search / bookmarked filters (requires user profile enhancement)
- Recurring event expansion (display each recurrence as separate event in results)
