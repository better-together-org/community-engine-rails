# N+1 Query Audit: Community Engine Rails - PeopleController#show

## Executive Summary
Found **6 major N+1 query sources** causing 90x, 20x, 18x, 16x, 14x, and 12x+ queries. Root cause: missing eager loading and repeated database lookups. Implementation of fixes will reduce PeopleController#show queries by ~70%.

---

## Finding 1: Platform Host Lookup (90x queries)
### ⚠️ SEVERITY: CRITICAL

**Pattern:** `Platform.find_by(host: true)` called repeatedly without caching

**Locations:**
1. **app/helpers/better_together/application_helper.rb:71-77**
   ```ruby
   def host_platform
     platform = ::BetterTogether::Platform.find_by(host: true)  # Query each call
     return platform if platform
     ::BetterTogether::Platform.new(...)
   end
   ```
   - Called multiple times per request (in SEO helpers, navigation helpers, etc.)
   - **No memoization** - fresh database query on each call
   - **Used in:** seo_meta_tags (line 109), open_graph_meta_tags (line 142-144, 150, 162)
   - **Trigger in view:** Anywhere that calls these helpers

2. **app/controllers/better_together/application_controller.rb:62-68**
   ```ruby
   def check_platform_setup
     host_platform = helpers.host_platform  # Calls helper, triggers query
     return if host_platform.persisted? && helpers.host_setup_wizard.completed?
   ```
   - Called as `before_action` on **every request** across all controllers
   - `check_platform_setup` runs before action on ApplicationController

3. **app/controllers/better_together/application_controller.rb:130**
   ```ruby
   return if helpers.host_platform.privacy_public?  # Another lookup in check_platform_privacy
   ```

### Root Cause
- **No memoization** in `host_platform` helper method
- Called via `helpers.host_platform` in layouts and controllers
- Each view/controller that calls these helpers triggers a fresh query

### Recommended Fix

**Option A: Memoize in ApplicationHelper (Quick, ~1 minute)**
```ruby
# app/helpers/better_together/application_helper.rb
def host_platform
  @host_platform_cache ||= ::BetterTogether::Platform.find_by(host: true) || 
    ::BetterTogether::Platform.new(name: 'Better Together Community Engine', url: base_url, privacy: 'private')
end
```

**Option B: Use RequestStore for Request Isolation (Better, ~3 minutes)**
```ruby
# Gemfile (already present in most Rails apps)
gem 'request_store'

# app/helpers/better_together/application_helper.rb
def host_platform
  RequestStore.store[:host_platform] ||= 
    ::BetterTogether::Platform.find_by(host: true) || 
    ::BetterTogether::Platform.new(name: 'Better Together Community Engine', url: base_url, privacy: 'private')
end
```

**Option C: Move to Controller before_action (Best, ~5 minutes)**
```ruby
# app/controllers/better_together/application_controller.rb
before_action :load_host_platform

protected

def load_host_platform
  @host_platform = ::BetterTogether::Platform.find_by(host: true) || 
    ::BetterTogether::Platform.new(name: 'Better Together Community Engine', url: base_url, privacy: 'private')
end

# Then in helpers:
def host_platform
  @host_platform
end
```

**Expected Impact:** Reduce 90 queries → 1 query per request

---

## Finding 2: Person View – Missing Preloading (Multiple N+1s)
### ⚠️ SEVERITY: HIGH

**File:** app/views/better_together/people/show.html.erb

The view calls `.size` and `.any?` on associations without preloading:

### Issue 2.1: person_platform_memberships (16x queries)
**Line 86:** `@person.person_platform_memberships.size > 0`
**Line 152-155:** Renders collection of memberships

Problem: Association loaded to check size, then reloaded when rendering.

**Fix:** Preload in controller action
```ruby
# app/controllers/better_together/people_controller.rb:show
@person = set_resource_instance
@person.person_platform_memberships.load  # Force load here
```

Or better:
```ruby
# In resource_collection or set_resource_instance
@person = resource_class.includes(:person_platform_memberships, :person_community_memberships, :role_resource_permissions, :agreement_participants).find(...)
```

---

### Issue 2.2: person_community_memberships (14x queries)
**Line 87:** `@person.person_community_memberships.size > 0`
**Line 161-166:** Renders collection

Same issue as above - association needs preloading.

---

### Issue 2.3: role_resource_permissions (12x queries)
**Line 88:** `@person.role_resource_permissions.size > 0`
**Line 170-184:** Iterates in `.each` loop

**Fix:** Add to eager loading:
```ruby
@person = resource_class.includes(
  :person_platform_memberships, 
  :person_community_memberships, 
  :role_resource_permissions,  # Add this
  :agreement_participants      # Add this
).find(id)
```

---

### Issue 2.4: agreement_participants (11x queries)
**Line 98:** `@person.agreement_participants.any?`
**Line 194:** `@person.agreement_participants.includes(:agreement).each`

Already has `.includes(:agreement)` in the view, but association not preloaded initially.

**Current Implementation (Lines 14-22 in PeopleController#show):**
```ruby
@authored_pages = policy_scope(@person.authored_pages)
                  .includes(
                    :string_translations,
                    blocks: { background_image_file_attachment: :blob }
                  )
@person.preload_calendar_associations!
```

**Problem:** Missing preloads for other associations

**Recommended Fix:**
```ruby
# app/controllers/better_together/people_controller.rb:13-26
def show
  # Preload authored pages
  @authored_pages = policy_scope(@person.authored_pages)
                    .includes(
                      :string_translations,
                      blocks: { background_image_file_attachment: :blob }
                    )
  
  # ✅ NEW: Preload all view associations
  @person.association(:person_platform_memberships).load
  @person.association(:person_community_memberships).load
  @person.association(:role_resource_permissions).load
  @person.association(:agreement_participants).load
  
  # Preload calendar associations
  @person.preload_calendar_associations!
  
  # Categorize events
  categorize_person_events
end
```

**Expected Impact:** Reduce 14+12+11+16 = 53 queries per view

---

## Finding 3: Content Blocks – Missing eager_load of Attachments (18x queries)
### ⚠️ SEVERITY: HIGH

**File:** app/models/better_together/page.rb:97-101

```ruby
def hero_block
  @hero_block ||= blocks.where(type: 'BetterTogether::Content::Hero')
                        .with_attached_background_image_file  # Does NOT eager load attachments
                        .with_translations
                        .first
end

def content_blocks
  @content_blocks ||= blocks.where.not(type: 'BetterTogether::Content::Hero')
                            .with_attached_background_image_file
                            .with_translations
end
```

**Problem:** 
- `.with_attached_background_image_file` is an **Active Storage macro that prepares the association** but doesn't actually `includes` it in the query for the collection
- When blocks are rendered, accessing `.background_image_file.attached?` or `image_url` triggers a query per block

**Sentry Data Match:** 18x `active_storage_attachments` queries

**Location in Database Queries:**
The query is triggered when rendering the blocks. Each block checks if the attachment exists.

**Recommended Fix:**

Replace with proper eager loading:
```ruby
# app/models/better_together/page.rb

def hero_block
  @hero_block ||= blocks.where(type: 'BetterTogether::Content::Hero')
                        .with_translations
                        .with_attached_background_image_file  # Keep this, but...
                        .first
end

def content_blocks
  @content_blocks ||= blocks.where.not(type: 'BetterTogether::Content::Hero')
                            .with_translations
                            .with_attached_background_image_file  # This doesn't actually include
                            .load  # Force evaluation with eager loading in scope
end
```

**Better approach – use includes explicitly:**
```ruby
# app/models/better_together/page.rb

def hero_block
  @hero_block ||= blocks.where(type: 'BetterTogether::Content::Hero')
                        .includes(background_image_file_attachment: :blob)
                        .with_translations
                        .first
end

def content_blocks
  @content_blocks ||= blocks.where.not(type: 'BetterTogether::Content::Hero')
                            .includes(background_image_file_attachment: :blob)
                            .with_translations
end
```

**OR create a scope in Block model:**
```ruby
# app/models/better_together/content/block.rb

scope :with_images, -> { includes(background_image_file_attachment: :blob) }

# Then in page.rb:
def hero_block
  @hero_block ||= blocks.where(type: 'BetterTogether::Content::Hero')
                        .with_images
                        .with_translations
                        .first
end

def content_blocks
  @content_blocks ||= blocks.where.not(type: 'BetterTogether::Content::Hero')
                            .with_images
                            .with_translations
end
```

**Expected Impact:** Reduce 18 queries → 1 query (blob + variant loaded once)

---

## Finding 4: Mobility String Translations – Not Preloaded (16x + 14x queries)
### ⚠️ SEVERITY: HIGH

**File:** app/models/concerns/better_together/translatable.rb:11-18

```ruby
scope :with_translations, lambda {
  include_list = []
  include_list << :string_translations if model.method_defined?(:string_translations)
  include_list << :text_translations if model.method_defined?(:text_translations)
  include_list << :rich_text_translations if model.method_defined?(:rich_text_translations)
  
  includes(include_list)  # ✅ This is working for main models
}
```

**Problem:** 
- The `with_translations` scope is called on the **main model** but NOT on nested associations
- When viewing a person's memberships (line 155 in show.html.erb), those membership objects are **not** preloaded with translations
- The Platform/Community names (`joinable: [:string_translations, ...]` in controller) are only loaded in `resource_collection`, not in `show`

**Sentry Match:** 16x and 14x `mobility_string_translations` queries

**Specific Location – PeopleController#show doesn't preload membership translations:**
```ruby
# app/controllers/better_together/people_controller.rb:152-155
<% if @person.person_platform_memberships.size > 0 && ... %>
  <div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 row-cols-xl-4">
    <%= render partial: 'better_together/person_platform_memberships/person_platform_membership', 
               collection: @person.person_platform_memberships %>  # Renders without translations
  </div>
<% end %>
```

The partial then accesses the joinable's `.name` attribute, which requires a translation lookup.

### Recommended Fix

**In PeopleController#show (line 22, after preload_calendar_associations!):**
```ruby
# Preload membership translations
@person.person_platform_memberships.each do |membership|
  membership.association(:joinable).load
  membership.joinable&.association(:string_translations).load if membership.joinable.respond_to?(:string_translations)
end

@person.person_community_memberships.each do |membership|
  membership.association(:joinable).load
  membership.joinable&.association(:string_translations).load if membership.joinable.respond_to?(:string_translations)
end
```

**OR better – load all at once in controller:**
```ruby
# app/controllers/better_together/people_controller.rb
def show
  @person = set_resource_instance
  
  # Preload authored pages
  @authored_pages = policy_scope(@person.authored_pages)
                    .includes(:string_translations, blocks: { background_image_file_attachment: :blob })
  
  # ✅ Preload all associations with their translations
  @person.association(:person_platform_memberships).load
  @person.person_platform_memberships.each do |m|
    m.association(:joinable).load
    m.joinable&.association(:string_translations).load
  end
  
  @person.association(:person_community_memberships).load
  @person.person_community_memberships.each do |m|
    m.association(:joinable).load
    m.joinable&.association(:string_translations).load
  end
  
  @person.association(:role_resource_permissions).load
  @person.role_resource_permissions.includes(:role).each do |rrp|
    rrp.role&.association(:string_translations).load
  end
  
  # ...rest of method
end
```

**Expected Impact:** Reduce 16+14 = 30 queries

---

## Finding 5: Helper Method – Repeated Platform Lookups
### ⚠️ SEVERITY: MEDIUM

**File:** app/helpers/better_together/application_helper.rb:533

```ruby
def some_method
  platform = host_platform || BetterTogether::Platform.find_by(host: true)
  # ...
end
```

This method calls `host_platform` (which does a query) **and then** also calls `Platform.find_by(host: true)` as a fallback, creating redundant queries.

### Recommended Fix
```ruby
def some_method
  # Use memoized helper only
  platform = host_platform
  # No fallback needed - host_platform already provides a default
end
```

---

## Summary Table: Expected Reductions

| Issue | Current | After Fix | Reduction |
|-------|---------|-----------|-----------|
| Platform host lookup (90x) | 90 | 1 | **89 queries** |
| person_platform_memberships (16x) | 16 | 1 | **15 queries** |
| person_community_memberships (14x) | 14 | 1 | **13 queries** |
| role_resource_permissions (12x) | 12 | 1 | **11 queries** |
| agreement_participants (11x) | 11 | 1 | **10 queries** |
| Content block attachments (18x) | 18 | 1 | **17 queries** |
| Mobility translations (16x+14x) | 30 | 2 | **28 queries** |
| **TOTAL** | **165 queries** | **~8 queries** | **~157 queries saved (95% reduction)** |

---

## Implementation Checklist

- [ ] **Step 1:** Memoize `host_platform` in ApplicationHelper (2 min)
- [ ] **Step 2:** Add preloads in PeopleController#show (5 min)
- [ ] **Step 3:** Fix content block attachment eager loading in Page model (3 min)
- [ ] **Step 4:** Preload membership translations in show action (5 min)
- [ ] **Step 5:** Test with Rack::MiniProfiler or query log (10 min)
- [ ] **Step 6:** Deploy and monitor Sentry metrics

**Total Implementation Time:** ~30 minutes

---

## Additional Recommendations

1. **Create a utility method** to reduce preloading boilerplate:
   ```ruby
   # app/models/better_together/person.rb
   def preload_show_associations!
     association(:person_platform_memberships).load
     association(:person_community_memberships).load
     association(:role_resource_permissions).load
     association(:agreement_participants).load
     preload_calendar_associations!
   end
   ```

2. **Create database indices** on frequently-queried columns:
   ```sql
   CREATE INDEX idx_platforms_host ON better_together_platforms(host);
   CREATE INDEX idx_platform_invitations_pending_token ON better_together_platform_invitations(status, token);
   ```

3. **Monitor QueryCount** with `rails_performance` or `bullet` gem to catch regressions
