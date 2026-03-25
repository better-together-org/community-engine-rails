# Plan: Posts Index — Search, Filter Sidebar, Pagination

**Tracking issue:** better-together-org/community-engine-rails#1407
**Related plans:**
- [Federation authorship opt-in](federation-authorship-opt-in.md) — branch `plan/federation-authorship-opt-in`
- [Events index search/filter/pagination](events-index-filter-pagination.md) — branch `plan/events-index-filter-pagination`

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

## Out of Scope

- Full-text search via Elasticsearch (post index may not have ES enabled on all platforms).
  Use SQL `ILIKE` + Mobility joins as in `Joatu::SearchFilter`.
- Saved search / bookmarked filters.
- Map or calendar view modes.

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

## Required Tests

- [ ] **`PostsSearchFilter` unit spec** (no Rails load; pure AR relation mocking):
  - no params → returns full unfiltered relation
  - `q: "hello"` → applies ILIKE condition
  - `category_ids: [id]` → joins categories and filters
  - `privacy: "public"` → filters by privacy column
  - `order_by: "oldest"` → orders ascending
  - `per_page: 10` → Kaminari `.per(10)` applied
- [ ] **`PostsController` request spec** (`GET /en/posts`):
  - returns 200 with no params
  - filters by `q`, `category_ids`, `privacy` and returns correct subset
  - paginates: page 2 with per_page 10 returns correct window
- [ ] **System/feature spec**:
  - Visit posts index; type search term; assert filtered results
  - Select a category; assert only posts in that category shown
  - Navigate to page 2; assert pagination links present and correct posts shown

---

## Stakeholders

| Name | Role |
|------|------|
| Rob Polowick | Product lead |
| Platform managers | Observe posts index in production; need usable browse UX |
| Community Engine users | Browse and search posts |

---

## Implementation Notes

- `FriendlyResourceController#resource_collection` already builds the base policy-scoped
  relation and is the right integration point. Override it in `PostsController` to
  pass through the search filter before returning.
- The Joatu `SearchFilter` joins are written for `BetterTogether::Joatu::Offer`/`Request`
  but the Mobility table structure is identical for posts. The join logic can be extracted
  into a base module `BetterTogether::ContentSearchFilter::MobilityTitleJoin` if both
  posts and events need it.
- Category filter for posts: check whether posts are already `Categorizable`; if not,
  the category filter step is a no-op (handled gracefully in the service).
- Kaminari is already a dependency — no new gems required.
- The filter form uses GET (not POST) so filters are bookmarkable and shareable via URL.

---

## File Sketch

```
app/
  controllers/better_together/posts_controller.rb   (extend index action)
  services/better_together/posts_search_filter.rb   (new)
  views/better_together/posts/
    index.html.erb                                   (update)
    _list_form.html.erb                              (new)
config/locales/en.yml                               (add posts.index.* keys)
spec/
  services/better_together/posts_search_filter_spec.rb  (new)
  requests/better_together/posts_spec.rb            (extend)
  system/better_together/posts_index_spec.rb        (new or extend)
```
