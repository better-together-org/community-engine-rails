# Plan: Posts Index — Search, Filter Sidebar, Pagination

**v0.12.0 Release** | **Tracking issue:** better-together-org/community-engine-rails#1407

**Related plans:**
- [Federation authorship opt-in](federation-authorship-opt-in.md) — PR #1408 (`plan/federation-authorship-opt-in`)
- [Events index search/filter/pagination](events-index-filter-pagination.md) — PR #1410 (`plan/events-index-filter-pagination`) — **mirrors this pattern**

**Reference:** [v0.12.0 Stakeholder-Centered Acceptance Criteria Framework](../implementation/STAKEHOLDER_AC_IMPLEMENTATION_GUIDE.md)

---

## Background

The posts index currently renders every visible post in a flat list with no text search,
no category/status filtering, and no pagination. As platforms accumulate federated content
(mixed local + federated posts from multiple source platforms), the index becomes
unusable at scale. The Joatu offers and requests index already has the correct UX pattern:
a filter sidebar with free-text search, category multi-select, status dropdown, order-by,
and per-page selector backed by `Joatu::SearchFilter` and Kaminari.

Posts should adopt the same pattern.

---

## Goals

1. Add text search, optional category filter, privacy/status filter, and order-by to
   the posts index.
2. Add Kaminari pagination.
3. Add a filter sidebar partial consistent with the Joatu offers/requests index style.
4. Support federated vs. local post filtering (optional v1 stretch goal).
5. Reuse or generalise `Joatu::SearchFilter` where possible; extract shared logic into
   a base `ContentSearchFilter` if it reduces duplication.

---

## v0.12.0 Stakeholder Outcomes

This feature serves three distinct outcomes in the v0.12.0 framework:

| Stakeholder | Need | Success Metric |
|------------|------|-----------------|
| **Community Members** | "I can find posts about topics I care about" | Text search + category filter usable; results ≤ 2s |
| **Platform Managers** | "The index is usable when we have 100+ posts" | Pagination prevents page bloat; default 20/page ≤ 500ms |
| **Content Creators** | "My posts are discoverable" | Posts sort newest-first by default; option for oldest |

Implementation follows the **test-first cadence**: pending RSpec specs → implement → validate each week.

---

## Out of Scope

- Elasticsearch integration (v0.12.0 standardizes on pgsearch/SQL ILIKE across all platforms).
- Saved search / bookmarked filters (possible v0.12.1 enhancement).
- Map or calendar view modes (possible v0.12.1+ feature).

---

## Acceptance Criteria

### Controller (`PostsController#index`)

- [ ] `PostsController#index` applies a `PostsSearchFilter` (or equivalent) to the
      policy-scoped collection before rendering.
- [ ] Accepted params: `q` (text search), `category_ids[]`, `privacy` (public/private/
      community), `order_by` (newest/oldest), `per_page` (10/20/50), `page`.
- [ ] Params are passed through to the view for form state persistence (selected filters
      remain checked/filled on page reload).
- [ ] Default: 20 per page, ordered newest-first.

### Search / filter service (`PostsSearchFilter`)

- [ ] Implemented as a service object under `BetterTogether::` following
      `Joatu::SearchFilter` pattern: `call(resource_class:, relation:, params:)`.
- [ ] `search_text` step: ILIKE join on Mobility `mobility_string_translations` (title key)
      and ActionText `action_text_rich_texts` (content name), with locale fallback.
- [ ] `filter_by_categories` step: joins `better_together_categorizations` and
      `better_together_categories` when `params[:category_ids]` is present.
- [ ] `filter_by_privacy` step: filters by `privacy` column when param is present.
- [ ] `order_by` step: `created_at desc` (default) or `created_at asc`.
- [ ] `paginate` step: `.page(params[:page]).per(per_page)` via Kaminari.
- [ ] Returns a Kaminari-decorated relation.

### View

- [ ] `app/views/better_together/posts/index.html.erb` updated to:
  - Render `_list_form` sidebar partial (GET form, consistent with Joatu style).
  - Render paginated post cards / list items.
  - Show `paginate @posts` Kaminari navigation.
  - Show result count: "X posts" (with active filter indicator if filters applied).
- [ ] `app/views/better_together/posts/_list_form.html.erb` new partial:
  - Text search input (`q`).
  - Category checkboxes (dynamically loaded from `BetterTogether::Category` scoped to posts).
  - Privacy select (All / Public / Community / Private).
  - Order-by select (Newest / Oldest).
  - Per-page select (10 / 20 / 50).
  - Submit button; clear-filters link.
- [ ] Filter sidebar is collapsible on mobile (consistent with Joatu implementation).

### i18n

- [ ] All new UI strings added to `config/locales/en.yml` under
      `better_together.posts.index.*`.

---

## Test-First Implementation (v0.12.0 Framework)

All specs are **pending** until implementation week; run with:
```bash
rspec spec/acceptance_criteria/posts_index_spec.rb --tag acceptance_criteria --pending
```

### Required Test Suite: `spec/acceptance_criteria/posts_index_spec.rb`

**Model Layer (Week 1 — Service foundation)**
- [ ] `PostsSearchFilter.call(relation:, params:)` returns Kaminari-decorated relation
- [ ] `q: "hello"` applies ILIKE to Mobility title + ActionText content (both locales)
- [ ] `category_ids: [id]` joins categorizations and returns only tagged posts
- [ ] `privacy: "public"` filters by posts.privacy column
- [ ] `order_by: "oldest"` orders `created_at asc` (default is `desc`)
- [ ] `per_page: 10` applies Kaminari `.per(10)`, defaults to 20
- [ ] Empty params returns full unfiltered relation (no N+1 joins)

**Request Layer (Week 2 — Controller + authorization)**
- [ ] `GET /en/posts` with no params returns 200, all visible posts, 20 per page
- [ ] `?q=foo` filters results, params persist in view
- [ ] `?category_ids[]=1&category_ids[]=2` multi-select works
- [ ] `?privacy=community` restricts to community-only posts
- [ ] `?order_by=oldest` reverses sort order
- [ ] `?page=2&per_page=10` paginates correctly
- [ ] Authorization: respects policy scope (user sees only permitted posts)

**Feature Layer (Week 3 — UX + pagination)**
- [ ] Visit `/en/posts`, see filter sidebar with all controls
- [ ] Type in search box, submit form, results filter in real-time
- [ ] Check category checkboxes (multi-select), results update
- [ ] Select privacy dropdown, results filter
- [ ] Select per-page, page reloads with new window size
- [ ] Pagination links present and navigate correctly
- [ ] "Clear filters" link resets to unfiltered state
- [ ] Sidebar collapses on mobile (≤768px)

---

## Stakeholders

| Name | Role |
|------|------|
| Rob Polowick | Product lead |
| Platform managers | Observe posts index in production; need usable browse UX |
| Community Engine users | Browse and search posts |

---

## Implementation Notes

**Search Strategy:** v0.12.0 standardizes on **pgsearch (PostgreSQL ILIKE)** across all platforms. No Elasticsearch detection or fallback; all deployments use SQL joins + ILIKE.

- `FriendlyResourceController#resource_collection` already builds the base policy-scoped
  relation and is the right integration point. Override it in `PostsController` to
  pass through the search filter before returning.

- **Mobility joins:** Text search joins `mobility_string_translations` (Mobility title key)
  and `action_text_rich_texts` (ActionText content), with locale scoping. Reference:
  `app/services/joatu/search_filter.rb` for join pattern.

- **Category filter:** Posts are `Categorizable`; join `better_together_categorizations`
  and `better_together_categories`. Multi-select on category IDs.

- **Privacy filter:** Use the `privacy` column directly (enum: public / community / private).
  Respect policy scope — don't expose filtering ui for states user can't see.

- **Reusable base:** Extract common logic into `BetterTogether::ContentSearchFilter` base
  class so `EventsSearchFilter` can inherit join + pagination steps. Both will override
  `#default_order_by` and filter-specific scopes.

- **Kaminari:** Already a dependency; use `.page(params[:page]).per(per_page)`.

- **GET form:** Filter form uses GET (not POST) so filters are bookmarkable (`/posts?q=foo&category_ids[]=1&page=2`).

**Events parity:** PR #1410 (`EventsSearchFilter`) will follow this exact pattern with status filter + date-range order-by instead of privacy + creation-date order-by.

---

## Implementation Sequence

```
Week 1: Model + Service Layer
  spec/acceptance_criteria/posts_index_spec.rb      (new; model specs — pending)
  app/services/better_together/posts_search_filter.rb  (new)
  app/services/better_together/content_search_filter.rb  (new base; extract reusable joins)

Week 2: Request + Controller Layer
  spec/acceptance_criteria/posts_index_spec.rb      (add request specs — pending)
  app/controllers/better_together/posts_controller.rb  (override resource_collection)

Week 3: View + i18n
  spec/acceptance_criteria/posts_index_spec.rb      (add feature specs — pending)
  app/views/better_together/posts/index.html.erb    (update; add sidebar + paginate)
  app/views/better_together/posts/_list_form.html.erb  (new)
  config/locales/en.yml                             (add posts.index.* keys)
```

**Parallel track (Week 1–3):** PR #1410 (Events) follows the same cadence using the base `ContentSearchFilter` from week 1.
