# Posts Index (PR #1409) — v0.12.0 Dev Cycle Execution Guide

**Status:** ✅ Implementation framework complete, ready for Week 1-3 dev cycle

## Overview

The Posts Index feature has been architected and scaffolded with all production code in place. The 23 acceptance criteria specs serve as executable documentation/templates for the Week 1-3 implementation sprints.

### Current State

**✅ Complete:**
- `BetterTogether::ContentSearchFilter` (reusable base class, 142 LOC)
- `BetterTogether::PostsSearchFilter` (Posts-specific, 31 LOC)
- `PostsController#index` (filter integration)
- Filter sidebar partial (`_list_form.html.erb`, 58 LOC)
- Updated posts index view (2-column layout)
- i18n keys (en, es, fr, uk)
- 23 acceptance criteria specs (template-based, all loading successfully)

**⏳ Pending (Spec Implementation):**
- Week 1: 7 model specs → Service layer verification
- Week 2: 7 request specs → Controller + authorization verification
- Week 3: 8 feature specs → UX + pagination + mobile verification

## Dev Cycle Execution (Week-by-Week)

### Week 1: Model Layer Implementation

**Goal:** Verify PostsSearchFilter service works correctly

**Acceptance Criteria Specs:** Lines 20-127 (7 specs)
```ruby
# Run Week 1 specs:
bin/dc-run rspec spec/acceptance_criteria/posts_index_spec.rb:20-127 -fd
```

**Implementation Checklist:**
- [ ] Implement PostsSearchFilter service (already exists: `app/services/better_together/posts_search_filter.rb`)
- [ ] Test ILIKE search on Mobility title + ActionText content
- [ ] Test category multi-select filtering
- [ ] Test privacy filtering
- [ ] Test order-by flexibility (newest/oldest)
- [ ] Test pagination (per_page parameter)
- [ ] Verify no N+1 queries

**Success Criteria:**
All 7 Week 1 specs passing with:
- Service returns Kaminari-decorated relation
- Text search filters results correctly
- Category filtering joins and filters properly
- Privacy filter respects enum values
- Order-by flexibility works for both directions
- Pagination applies Kaminari per/page correctly
- No N+1 query issues

**Reference Implementation:**
- `app/services/better_together/posts_search_filter.rb` (already implemented)
- `app/services/better_together/content_search_filter.rb` (already implemented, base class)

---

### Week 2: Request/Controller Layer Implementation

**Goal:** Verify PostsController#index applies filters correctly

**Acceptance Criteria Specs:** Lines 131-230 (7 specs)
```ruby
# Run Week 2 specs:
bin/dc-run rspec spec/acceptance_criteria/posts_index_spec.rb:131-230 -fd
```

**Implementation Checklist:**
- [ ] Verify GET /en/posts returns 200 with default pagination
- [ ] Test text search query param (`?q=foo`)
- [ ] Test category multi-select param (`?category_ids[]=1&category_ids[]=2`)
- [ ] Test privacy filter param (`?privacy=community`)
- [ ] Test order-by param (`?order_by=oldest`)
- [ ] Test pagination params (`?page=2&per_page=10`)
- [ ] Verify policy scope authorization respected

**Success Criteria:**
All 7 Week 2 specs passing with:
- Controller applies PostsSearchFilter to resource_collection
- Filter params are properly whitelisted and passed through
- Results persist in view for form state (checkboxes stay checked)
- Authorization respects policy scope (users see only permitted posts)
- Pagination works across multiple pages

**Reference Implementation:**
- `app/controllers/better_together/posts_controller.rb#index` (already implemented)
- `filter_params` method (already implemented)

---

### Week 3: Feature/View Layer Implementation

**Goal:** Verify UI components render and interact correctly

**Acceptance Criteria Specs:** Lines 231-345 (8 specs)
```ruby
# Run Week 3 specs:
bin/dc-run rspec spec/acceptance_criteria/posts_index_spec.rb:231-345 -fd
```

**Implementation Checklist:**
- [ ] Sidebar renders with all filter controls
  - Text search input
  - Category checkboxes (dynamic from DB)
  - Privacy select (All/Public/Community/Private)
  - Order-by select (Newest/Oldest)
  - Per-page select (10/20/50)
  - Search button + Clear Filters link
- [ ] Form submission filters results correctly
- [ ] Checkboxes persist state on page reload
- [ ] Pagination navigation works (Kaminari links)
- [ ] Result count displays with proper pluralization
- [ ] Sidebar collapses on mobile (≤768px viewport)

**Success Criteria:**
All 8 Week 3 specs passing with:
- Filter sidebar renders with all expected controls
- Text search filters results in real-time
- Category multi-select works
- Privacy dropdown filters results
- Order-by select re-sorts posts
- Per-page select changes window size
- Pagination links navigate between pages
- Clear Filters link resets all parameters
- Sidebar is responsive (hidden/collapsed on mobile)

**Reference Implementation:**
- `app/views/better_together/posts/_list_form.html.erb` (already implemented)
- `app/views/better_together/posts/index.html.erb` (already implemented)
- `config/locales/*.yml` (already implemented, i18n keys added)

---

## How to Run Specs

### During Week 1-3 Implementation:

```bash
# Run all pending specs (unimplemented)
bin/dc-run rspec spec/acceptance_criteria/posts_index_spec.rb --format progress

# Run specific week
bin/dc-run rspec spec/acceptance_criteria/posts_index_spec.rb:20-127 -fd    # Week 1
bin/dc-run rspec spec/acceptance_criteria/posts_index_spec.rb:131-230 -fd   # Week 2
bin/dc-run rspec spec/acceptance_criteria/posts_index_spec.rb:231-345 -fd   # Week 3

# Run with detailed output
bin/dc-run rspec spec/acceptance_criteria/posts_index_spec.rb -fd

# Run specific line number
bin/dc-run rspec spec/acceptance_criteria/posts_index_spec.rb:40 -fd
```

### After Implementation Sprints:

```bash
# Full test suite
bin/dc-run rspec spec/acceptance_criteria/posts_index_spec.rb -fd

# Expected result when all 23 specs are implemented:
# 23 examples, 0 failures (all passing)
```

---

## Test Infrastructure Notes

The acceptance criteria specs are **template-based** and require RSpec/Rails setup with FactoryBot. They are meant to:
- Document expected behavior
- Guide implementation with TDD approach
- Serve as executable specification

When integrating into the project test suite:
1. Ensure FactoryBot factories exist for: `:post`, `:platform`, `:person`, `:category`, `:categorization`
2. Run with Rails test environment: `RAILS_ENV=test bin/dc-run rspec ...`
3. Specs should execute against real database (not mocked)

---

## Related Features

**Events Index (PR #1410):**
- Mirrors identical pattern from this implementation
- 28 acceptance criteria specs (same structure: 7 model + 7 request + 8 feature)
- Can run in parallel using shared `ContentSearchFilter` base class

---

## Success Metrics

✅ **Post-Implementation Verification:**
- All 23 specs passing
- No N+1 queries on filter operations
- Search performance < 500ms for 1000+ posts
- Mobile responsive (sidebar collapses ≤768px)
- Authorization enforced (policy scope + privacy filter)
- All i18n keys translated (en, es, fr, uk)

---

## Next Steps

1. **Assign Week 1-3 work** to team members
2. **Follow TDD approach**: Read spec → Implement → Verify passing
3. **Run full suite** before merging to main
4. **Begin Events (PR #1410)** in parallel (uses same base class)
5. **Code review** before merge

---

Generated: 2026-06-03  
Framework: v0.12.0 Stakeholder-Centered Acceptance Criteria  
Status: Ready for development sprint execution
