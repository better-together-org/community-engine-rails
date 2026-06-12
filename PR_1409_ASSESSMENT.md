# PR #1409 Assessment & Plan Improvements

**Date:** 2026-06-03 | **Status:** ✅ **Plan improved, ready for implementation**

---

## Executive Summary

**PR #1409** is a **planning-phase artifact**, not a delivery. The plan document is now **v0.12.0-aligned** and ready to guide implementation.

| Item | Status | Action |
|------|--------|--------|
| **Plan document** | ✅ Improved | Integrated with v0.12.0 stakeholder-centered AC framework |
| **Implementation code** | ❌ Not started | 3-week sprint (Week 1: service layer, Week 2: controller, Week 3: views/i18n) |
| **CHANGELOG entry** | ⚠️ Incorrect | Listed as v0.11.0 complete; should be v0.12.0 planned |
| **Acceptance Criteria** | ✅ Defined | 12 model specs + 7 request specs + 8 feature specs |
| **Test Suite** | ⚠️ Not created | `spec/acceptance_criteria/posts_index_spec.rb` must be created with pending specs |

---

## Key Improvements Made to Plan

### 1. **v0.12.0 Alignment** ✅
- Added explicit v0.12.0 release marker
- Integrated stakeholder outcomes (Community Members, Platform Managers, Content Creators)
- Linked to v0.12.0 Stakeholder-Centered Acceptance Criteria Framework

### 2. **Search Strategy Clarification** ✅
- Removed Elasticsearch discussion entirely
- Explicitly stated: **pgsearch (PostgreSQL ILIKE)** only, no fallback detection
- All platforms standardized on SQL joins + ILIKE

### 3. **Test-First Structure** ✅
Replaced prose test plan with **executable RSpec framework**:
- **Model Layer (Week 1):** 7 specs for `PostsSearchFilter` service
- **Request Layer (Week 2):** 7 specs for controller + authorization
- **Feature Layer (Week 3):** 8 specs for UX + pagination + mobile

All marked as **pending** until implementation week (following v0.12.0 pattern).

### 4. **Events Parity Established** ✅
- Explicitly noted: `EventsSearchFilter` (PR #1410) mirrors this pattern exactly
- Extracted `ContentSearchFilter` base class as reusable component
- Both can run in parallel using the same weekly cadence

### 5. **Implementation Sequence Clarified** ✅
```
Week 1: Model + Service (service foundation)
  → posts_search_filter.rb
  → content_search_filter.rb (base class for Events to reuse)

Week 2: Request + Controller (authorization + filtering)
  → posts_controller.rb (override resource_collection)

Week 3: View + i18n (UX + localization)
  → posts/index.html.erb, _list_form.html.erb
  → config/locales/en.yml
```

**Parallel:** Events can start week 1 using the base class from posts week 1.

---

## Next Steps Before Implementation

### Immediate (this PR)

1. **✅ Commit plan improvements**
   ```bash
   git add docs/plans/posts-index-filter-pagination.md
   git commit -m "docs(plan): align posts-index with v0.12.0 stakeholder-centered framework, clarify pgsearch strategy, add test-first specs"
   ```

2. **Create `spec/acceptance_criteria/posts_index_spec.rb`** — Template skeleton
   ```ruby
   # spec/acceptance_criteria/posts_index_spec.rb
   describe 'Posts Index — Search, Filter & Pagination (v0.12.0)' do
     # Model Layer (Week 1)
     describe 'PostsSearchFilter' do
       pending 'PostsSearchFilter.call(relation:, params:) returns Kaminari-decorated relation' do
         # ...
       end
       
       pending 'q: "hello" applies ILIKE to Mobility title + ActionText content' do
         # ...
       end
       
       # ... (5 more pending model specs)
     end
     
     # Request Layer (Week 2)
     describe 'PostsController#index' do
       pending 'GET /en/posts with no params returns 200, all visible posts, 20 per page' do
         # ...
       end
       # ... (6 more pending request specs)
     end
     
     # Feature Layer (Week 3)
     describe 'Posts index UX' do
       pending 'Visit /en/posts, see filter sidebar with all controls' do
         # ...
       end
       # ... (7 more pending feature specs)
     end
   end
   ```

3. **Mirror for Events (PR #1410)** — Create `docs/plans/events-index-filter-pagination.md`
   Same structure as posts plan, but with:
   - Status filter instead of privacy
   - Date-range order-by (soonest/latest/newest/oldest) instead of creation order
   - Replaces four hardcoded partition variables (`@draft_events`, `@upcoming_events`, etc.)

### Before Week 1 Implementation

4. **Fix CHANGELOG** — Remove premature v0.11.0 entry:
   ```yaml
   # DELETE THIS from [0.11.0]:
   # #### Posts Index — Search, Filter & Pagination
   # - New `PostsSearchFilter` service: ...
   
   # ADD THIS to [0.12.0] (when/if it exists):
   # #### Posts & Events Indices — Unified Search & Filtering
   # - New `PostsSearchFilter` service: ILIKE text search (pgsearch), category filter, privacy filter, order-by, Kaminari pagination (#1409)
   # - New `EventsSearchFilter` service: ILIKE text search, category filter, status filter, flexible order-by (soonest/latest), Kaminari pagination (#1410)
   # - Reusable `ContentSearchFilter` base class for future filterable content
   ```

5. **Reference Implementation** — Check existing patterns:
   - `app/services/joatu/search_filter.rb` — Mobility title join pattern
   - `app/views/joatu/offers/index.html.erb` + `_list_form.html.erb` — Filter sidebar UX
   - `Kaminari` paginate calls in similar indices

---

## Clarifications Captured

| Question | Answer | Impact |
|----------|--------|--------|
| **Release scope?** | v0.12.0 (not v0.11.0) | Plan updated; CHANGELOG needs correction |
| **Search backend?** | pgsearch only (no ES) | Removes complexity; all platforms identical |
| **Events sync?** | Mirror Posts pattern exactly | Can run in parallel week 1–3 |

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|-----------|
| Mobility join complexity (locales) | Medium | Reference Joatu::SearchFilter; test both locales in specs |
| Privacy filter scope leakage | Medium | Spec includes policy scope test; respect authorization |
| Pagination edge cases (page=999) | Low | Kaminari handles gracefully; test boundary conditions |
| Mobile sidebar collapse | Low | Copy Joatu implementation (known working) |
| N+1 queries on category filter | Medium | Spec tests unfiltered relation; pre-load associations |

---

## Success Criteria (v0.12.0)

Implementation is **complete** when:

- [ ] All 22 pending specs in `posts_index_spec.rb` pass ✓
- [ ] `PostsController#index` applies `PostsSearchFilter` before render ✓
- [ ] Filter sidebar renders; all controls functional ✓
- [ ] Pagination works; default 20/page, newest-first ✓
- [ ] Authorization respected (policy scope + privacy filter) ✓
- [ ] i18n keys added under `better_together.posts.index.*` ✓
- [ ] Mobile sidebar collapses ≤768px ✓
- [ ] Events mirror with `EventsSearchFilter` in PR #1410 ✓

---

## Code Path Reference

**Files to create/modify:**

```
Week 1 (Service Foundation)
  spec/acceptance_criteria/posts_index_spec.rb        (new; model layer pending)
  app/services/better_together/posts_search_filter.rb (new)
  app/services/better_together/content_search_filter.rb (new base)

Week 2 (Controller + Auth)
  spec/acceptance_criteria/posts_index_spec.rb        (extend with request specs)
  app/controllers/better_together/posts_controller.rb (override resource_collection)

Week 3 (Views + i18n)
  spec/acceptance_criteria/posts_index_spec.rb        (extend with feature specs)
  app/views/better_together/posts/index.html.erb      (update)
  app/views/better_together/posts/_list_form.html.erb (new)
  config/locales/en.yml                               (add posts.index.*)
```

**Reference implementations:**
- `app/services/joatu/search_filter.rb` — Mobility join pattern
- `app/views/joatu/offers/_list_form.html.erb` — Filter sidebar UX
- `spec/requests/joatu/offers_spec.rb` — Controller tests pattern

---

## Commit Ready

Staged: `docs/plans/posts-index-filter-pagination.md` (+97 lines, -43 deletions)

When ready, commit with:
```bash
git commit -m "docs(plan): align posts-index with v0.12.0 stakeholder-centered framework, clarify pgsearch strategy, add test-first weekly cadence

- Integrated with v0.12.0 Stakeholder-Centered Acceptance Criteria Framework
- Search strategy: pgsearch (PostgreSQL ILIKE) only; no Elasticsearch
- Test-first structure: Model (Week 1) → Request (Week 2) → Feature (Week 3)
- Established Events mirror pattern for PR #1410
- Extracted ContentSearchFilter base class for reuse
- Clarified implementation sequence: 3-week sprint with parallel Events track"
```
