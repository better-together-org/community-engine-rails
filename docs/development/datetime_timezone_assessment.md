# DateTime and Timezone Support Assessment

**Date:** 2026-02-02  
**Status:** Assessment Complete  
**Related:** [Event Timezone DateTime Handling](event_timezone_datetime_handling.md)

## Executive Summary

After implementing timezone-aware datetime handling for Events, this assessment reviews all other datetime fields in forms across the Better Together Community Engine to determine if they require similar timezone support.

### Key Findings

- **Events** ✅ **FIXED** - Have timezone field and now properly handle datetime conversion
- **Posts** ⚠️ **NEEDS REVIEW** - Have `published_at` but NO timezone field (uses platform/user timezone)
- **Pages** ⚠️ **NEEDS REVIEW** - Have `published_at` but NO timezone field (uses platform/user timezone)
- **CallForInterest** ⚠️ **NEEDS REVIEW** - Have `starts_at`/`ends_at` but NO timezone field
- **PlatformInvitations** ✅ **OK** - `valid_from`/`valid_until` are admin-set, platform timezone is appropriate

---

## Detailed Assessment by Model

### 1. Events (✅ FIXED)

**Datetime Fields:**
- `starts_at` (datetime)
- `ends_at` (datetime)
- `timezone` (string, IANA identifier)

**Form Location:** `app/views/better_together/events/_event_datetime_fields.html.erb`

**Current Implementation:**
- ✅ Uses `datetime_local_field` for timezone-less browser input
- ✅ Controller converts datetime params to event's timezone before validation
- ✅ Helper method displays UTC values in event's timezone
- ✅ Comprehensive test coverage

**Status:** **COMPLETE** - Proper timezone support implemented.

---

### 2. Posts (⚠️ NEEDS REVIEW)

**Datetime Fields:**
- `published_at` (datetime, nullable)

**Timezone Field:** ❌ **NONE**

**Form Location:** `app/views/better_together/posts/_form.html.erb` (line 77)

**Current Implementation:**
```erb
<%= form.datetime_field :published_at, include_seconds: false, class: 'form-control' %>
```

**Issues:**
1. Uses `datetime_field` (deprecated, includes timezone offset)
2. No timezone field on Post model
3. DateTime interpreted in user's current timezone (from `Time.zone`)
4. Potential for confusion when:
   - User in Toronto (UTC-5) schedules post for "2:00 PM"
   - Post published at "2:00 PM Toronto time" (19:00 UTC)
   - Platform organizer in Vancouver (UTC-8) sees scheduled for "11:00 AM Vancouver time"

**Use Case Analysis:**
- Posts are content items that may be scheduled for publication
- Publication time is typically less critical than event times
- Most users likely think of "publish at 2pm" as "2pm in my timezone"
- However, platform-wide scheduled posts could benefit from explicit timezone

**Recommendations:**

#### Option A: Platform Timezone (Simple)
- Use platform's timezone for all `published_at` values
- Document that scheduled posts use platform timezone
- Add helper text: "Scheduled for 2:00 PM Platform Time (America/St_Johns)"
- **Pros:** Simple, consistent, no schema changes
- **Cons:** Confusing for multi-timezone platforms

#### Option B: Add Timezone Field (Complex)
- Add `timezone` field to Posts table
- Default to platform timezone on creation
- Allow organizers to override if needed
- **Pros:** Explicit, flexible
- **Cons:** Adds complexity, migration required

**Recommended Action:** **Option A** (Platform Timezone) with clear UI indicator.

---

### 3. Pages (⚠️ NEEDS REVIEW)

**Datetime Fields:**
- `published_at` (datetime, nullable)

**Timezone Field:** ❌ **NONE**

**Form Location:** `app/views/better_together/pages/_form.html.erb` (line 76)

**Current Implementation:**
```erb
<%= form.datetime_field :published_at, include_seconds: false, 
    class: "form-control#{' is-invalid' if page.errors[:published_at].any?}" %>
```

**Issues:**
- Same as Posts (above)
- Uses deprecated `datetime_field`
- No timezone field

**Use Case Analysis:**
- Pages are semi-static content (documentation, info pages)
- Publication timing typically even less critical than Posts
- Often published "immediately" rather than scheduled
- Platform timezone is likely sufficient

**Recommendations:**

Same as Posts - **Use Platform Timezone** with clear UI indicator.

**Recommended Changes:**
1. Change to `datetime_local_field` for consistency
2. Add helper text indicating platform timezone
3. Consider adding "Publish Now" button as alternative to datetime picker

---

### 4. CallsForInterest (⚠️ NEEDS REVIEW)

**Datetime Fields:**
- `starts_at` (datetime, nullable)
- `ends_at` (datetime, nullable)

**Timezone Field:** ❌ **NONE**

**Form Location:** `app/views/better_together/calls_for_interest/_form.html.erb` (lines 93, 105)

**Current Implementation:**
```erb
<%= form.datetime_field :starts_at, include_seconds: false, class: 'form-control' %>
<%= form.datetime_field :ends_at, include_seconds: false, class: 'form-control' %>
```

**Issues:**
- Uses `datetime_field` (deprecated)
- No timezone field
- **Critical:** Calls for Interest are time-sensitive opportunities
- Similar to Events, they represent real-world occurrences with specific times

**Use Case Analysis:**
- Calls for Interest may represent:
  - Application deadlines
  - Submission windows
  - Time-limited opportunities
- Users need to know "when does this end?" in their timezone
- Could be displayed to users across multiple timezones

**Recommendations:**

#### Option A: Add Timezone Field (Recommended)
- Add `timezone` string field to `CallsForInterest` table
- Default to platform timezone
- Allow organizers to set explicit timezone
- Implement same pattern as Events:
  - Controller-level datetime conversion
  - Helper methods for display
  - `datetime_local_field` in forms

#### Option B: Platform Timezone Only
- Document that all times are in platform timezone
- Add clear UI indicators
- Less flexible but simpler

**Recommended Action:** **Option A** - Add timezone support (high priority, similar to Events).

---

### 5. PlatformInvitations (✅ OK)

**Datetime Fields:**
- `valid_from` (datetime, required)
- `valid_until` (datetime, nullable)
- `last_sent` (datetime, nullable)
- `accepted_at` (datetime, nullable)

**Timezone Field:** ❌ **NONE**

**Form Location:** `app/views/better_together/platform_invitations/index.html.erb` (lines 45, 49)

**Current Implementation:**
```erb
<%= form.datetime_field :valid_from, include_seconds: false, 
    class: "form-control", value: Time.zone.now, required: true %>
<%= form.datetime_field :valid_until, include_seconds: false, class: "form-control" %>
```

**Use Case Analysis:**
- Invitations created by platform organizers
- Validity window is administrative/security feature
- Not displayed to end users
- Platform timezone is appropriate context

**Issues:**
- Uses deprecated `datetime_field` (minor)
- Hard-coded `Time.zone.now` default (minor)

**Recommendations:**

**LOW PRIORITY** - Platform timezone is appropriate for administrative records.

**Optional Improvements:**
1. Change to `datetime_local_field` for consistency
2. Move default value to controller/model

**Status:** **ACCEPTABLE AS-IS** - No timezone field needed.

---

## Other Datetime Fields (Not in Forms)

The following datetime fields exist but are **NOT user-editable** via forms:

### Metrics Tables
- `better_together_metrics_search_queries.searched_at`
- `better_together_metrics_downloads.downloaded_at`
- `better_together_metrics_shares.shared_at`
- `better_together_metrics_link_clicks.clicked_at`

**Status:** ✅ **OK** - System-generated timestamps, UTC storage appropriate.

### Joatu/Agreement Tables
- `better_together_agreement_participants.accepted_at`

**Status:** ✅ **OK** - System-generated, records point-in-time acceptance.

### Content Management
- `better_together_content_links.last_checked_at`

**Status:** ✅ **OK** - System-generated maintenance timestamp.

### Checklist Items
- `better_together_person_checklist_items.completed_at`

**Status:** ✅ **OK** - System-generated completion timestamp.

### AI Logging
- `better_together_ai_log_translations.start_time`
- `better_together_ai_log_translations.end_time`

**Status:** ✅ **OK** - System performance metrics, UTC appropriate.

---

## Summary of Recommended Actions

### High Priority (Timezone Field Needed)

1. **CallsForInterest** - Add timezone field and implement Event-like handling
   - Similar to Events, represents time-sensitive real-world occurrences
   - Users across timezones need accurate deadline information

### Medium Priority (Platform Timezone + Clear UI)

2. **Posts** - Use platform timezone with clear UI indicators
   - Change `datetime_field` → `datetime_local_field`
   - Add helper text showing platform timezone
   - Document scheduled publication behavior

3. **Pages** - Use platform timezone with clear UI indicators
   - Change `datetime_field` → `datetime_local_field`
   - Add helper text showing platform timezone
   - Consider "Publish Now" button

### Low Priority (Optional Improvements)

4. **PlatformInvitations** - Cosmetic improvements only
   - Change `datetime_field` → `datetime_local_field` for consistency
   - Move default value from view to controller

---

## Implementation Checklist

### For CallsForInterest (High Priority)

- [ ] Generate migration to add `timezone` string field
- [ ] Add timezone validation (IANA identifiers)
- [ ] Include `TimezoneAttributeAliasing` concern
- [ ] Add `before_action :convert_datetime_params_to_call_timezone` in controller
- [ ] Implement `convert_datetime_params_to_call_timezone` method
- [ ] Add helper method `call_datetime_field_value(call, field)`
- [ ] Update form to use `datetime_local_field` with helper
- [ ] Add timezone selector to form
- [ ] Write comprehensive RSpec tests
- [ ] Update documentation

### For Posts/Pages (Medium Priority)

- [ ] Change `datetime_field` → `datetime_local_field`
- [ ] Add helper text showing platform timezone context
- [ ] Add model method to interpret `published_at` in platform timezone
- [ ] Document behavior in UI and developer docs
- [ ] Add/update RSpec tests for timezone interpretation
- [ ] Consider adding "Publish Now" convenience button

### For PlatformInvitations (Low Priority)

- [ ] Change `datetime_field` → `datetime_local_field`
- [ ] Move `value: Time.zone.now` to controller default
- [ ] Update tests if needed

---

## References

- [Event Timezone DateTime Handling](event_timezone_datetime_handling.md) - Complete implementation guide
- [Timezone Handling Strategy](timezone_handling_strategy.md) - Architecture documentation
- `app/concerns/better_together/timezone_attribute_aliasing.rb` - Timezone concern
- `config/locales/en.yml` - Timezone-related translations

---

## Decision Log

| Date | Model | Decision | Rationale |
|------|-------|----------|-----------|
| 2026-02-02 | Event | Add timezone field | Events represent specific moments in time across timezones |
| 2026-02-02 | CallForInterest | **PENDING** | Similar to Events, time-sensitive with cross-timezone concerns |
| 2026-02-02 | Post | **PENDING** | Publication scheduling, platform timezone likely sufficient |
| 2026-02-02 | Page | **PENDING** | Publication scheduling, platform timezone likely sufficient |
| 2026-02-02 | PlatformInvitation | No timezone field | Administrative records, platform timezone appropriate |

---

## Next Steps

1. **Discuss with stakeholders:** Which models need timezone fields vs platform timezone?
2. **Prioritize implementation:** CallsForInterest first (high impact), then Posts/Pages
3. **Create tracking issues:** One issue per model for implementation
4. **Follow Event pattern:** Reuse architecture and test patterns from Event implementation
5. **Update documentation:** Keep this assessment updated as decisions are made
