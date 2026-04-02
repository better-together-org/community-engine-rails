# Plan: Events Index — Search, Filter Sidebar, Pagination

**Tracking issue:** better-together-org/community-engine-rails#1407
**Related plans:**
- [Federation authorship opt-in](federation-authorship-opt-in.md) — PR #1408 (`plan/federation-authorship-opt-in`)
- [Posts index search/filter/pagination](posts-index-filter-pagination.md) — PR #1409 (`plan/posts-index-filter-pagination`)

---

## Background

`EventsController#index` currently partitions events into four hardcoded scopes —
`@draft_events`, `@upcoming_events`, `@ongoing_events`, `@past_events` — and renders
all four lists with no search, no category filtering, and no per-section pagination.
This approach breaks down at scale: a platform with hundreds of events renders
everything at once, and there is no way for a user to search or narrow the list.

The Joatu offers and requests index already has the correct UX pattern (filter sidebar,
text search, Kaminari pagination). Events should adopt the same pattern, while
preserving the time-partitioned view as an optional "by status" filter rather than a
hard layout constraint.

---

## Goals

1. Replace the four-partition layout with a single filtered, paginated event list.
2. Add text search, category filter, status filter (draft/upcoming/ongoing/past),
   date range filter (optional v1 stretch), and order-by.
3. Add a filter sidebar partial consistent with the Joatu style.
4. Add Kaminari pagination.
5. Preserve the current status-partitioned layout as a "group by status" view option
   (or remove entirely — decide during implementation based on usage).

---

## Out of Scope

- Calendar/month view for events — separate future feature.
- RSVP counts in the index listing (already partially available; no change required).
- Federated event filtering by source platform (stretch — see federation authorship PR).

---

## Acceptance Criteria

### Controller (`EventsController#index`)

- [ ] `EventsController#index` applies an `EventsSearchFilter` to the policy-scoped,
      includes-preloaded collection before rendering.
- [ ] Accepted params: `q` (text search), `category_ids[]`, `status`
      (draft/upcoming/ongoing/past), `order_by` (soonest/latest/newest/oldest),
      `per_page` (10/20/50), `page`.
- [ ] Default: `status: upcoming`, ordered soonest-first (ascending `starts_at`),
      20 per page.
- [ ] The four `@draft_events` / `@upcoming_events` / `@ongoing_events` / `@past_events`
      instance variables are replaced by a single `@events` paginated relation.
      (Existing partitioned view templates updated or removed.)

### Search / filter service (`EventsSearchFilter`)

- [ ] Implemented as `BetterTogether::EventsSearchFilter` following
      `Joatu::SearchFilter` pattern.
- [ ] `search_text` step: ILIKE join on Mobility `mobility_string_translations`
      (name key) and ActionText `action_text_rich_texts` (description name), with
      locale fallback.
- [ ] `filter_by_categories` step: joins categorizations when `category_ids` present.
- [ ] `filter_by_status` step: maps param to AR scope (`draft`, `upcoming`, `ongoing`,
      `past`) — these scopes already exist on `BetterTogether::Event`.
- [ ] `order_by` step:
      - `soonest` → `starts_at asc` (default for upcoming)
      - `latest`  → `starts_at desc`
      - `newest`  → `created_at desc`
      - `oldest`  → `created_at asc`
- [ ] `paginate` step: Kaminari `.page.per`.

### View

- [ ] `app/views/better_together/events/index.html.erb` updated to:
  - Render `_list_form` sidebar.
  - Render paginated event cards.
  - Show `paginate @events` Kaminari navigation.
  - Show result count.
- [ ] `app/views/better_together/events/_list_form.html.erb` new partial:
  - Text search input (`q`).
  - Status select (All / Upcoming / Ongoing / Past / Draft).
  - Category checkboxes.
  - Order-by select (Soonest / Latest / Newest / Oldest).
  - Per-page select (10 / 20 / 50).
  - Submit button; clear-filters link.
- [ ] Filter sidebar is collapsible on mobile.

### i18n

- [ ] All new UI strings under `better_together.events.index.*` in `config/locales/en.yml`.
- [ ] Status option labels reuse existing `better_together.enums.event.status.*` keys
      where they exist.

---

## Required Tests

- [ ] **`EventsSearchFilter` unit spec**:
  - no params → returns full unfiltered relation
  - `q: "workshop"` → applies ILIKE condition on name/description
  - `category_ids: [id]` → joins and filters by category
  - `status: "upcoming"` → applies `.upcoming` scope
  - `order_by: "latest"` → orders by `starts_at desc`
  - `per_page: 10` → Kaminari `.per(10)` applied
- [ ] **`EventsController` request spec** (`GET /en/events`):
  - returns 200 with no params
  - `status: upcoming` returns only upcoming events
  - text search filters by event name
  - page 2 with per_page 10 returns correct window
- [ ] **System/feature spec**:
  - Visit events index; assert upcoming events shown by default
  - Select "Past" status; assert past events shown
  - Search for event name; assert filtered results
  - Navigate to page 2 via pagination links

---

## Stakeholders

| Name | Role |
|------|------|
| Rob Polowick | Product lead |
| Platform managers | Monitor and curate event listings |
| Community Engine users | Discover and browse events |
| Event hosts (people, communities, partners, venues) | Their events must remain findable |

---

## Implementation Notes

- The existing `Event` scopes (`draft`, `upcoming`, `ongoing`, `past`) are defined on
  the model. `EventsSearchFilter#filter_by_status` should call the named scope directly
  rather than re-implementing the date arithmetic.
- `resource_collection` in `EventsController` already calls `.includes(:categories)`;
  this should be preserved or extended to include `:event_hosts` for the index card
  rendering to avoid N+1 queries.
- The four `@draft_events`/`@upcoming_events`/etc. variables are only used in the
  events index template and its partials. Audit all `render partial: 'events/...'`
  calls before removing them to avoid breaking other views.
- If the partitioned layout is popular / important to preserve, add a `view: grouped`
  param that switches back to the four-section render path. Default to paginated single
  list for new installs.
- Consider extracting shared Mobility text-search join logic into a concern
  `BetterTogether::Concerns::MobilitySearchable` to be used by both
  `PostsSearchFilter` and `EventsSearchFilter`.

---

## File Sketch

```
app/
  controllers/better_together/events_controller.rb  (refactor index action)
  services/better_together/events_search_filter.rb  (new)
  views/better_together/events/
    index.html.erb                                   (update)
    _list_form.html.erb                              (new)
config/locales/en.yml                               (add events.index.* keys)
spec/
  services/better_together/events_search_filter_spec.rb  (new)
  requests/better_together/events_spec.rb           (extend)
  system/better_together/events_index_spec.rb       (new or extend)
```
