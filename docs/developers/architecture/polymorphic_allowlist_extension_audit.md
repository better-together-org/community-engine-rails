# Polymorphic Allow-List Audit: `included_in_models` vs Hardcoded `ALLOWED_*` Arrays

**Date:** 2026-07-10
**Author:** Claude (agent session), reviewed by Rob Smith
**Status:** Findings report — precedes the conversion of the 4 approved candidates below

## Design principle established during this audit

Community Engine is a platform-builder gem meant to be extended by the host apps built on
top of it. When a host-app developer wants their own model to participate in a cross-cutting
behavior (comments, reports, share tracking, short links, ...), the intended mechanism is:

```ruby
class TheirModel < ApplicationRecord
  include BetterTogether::Commentable
end
```

That `include` is itself the deliberate, reviewable decision — nothing else should need to
change. A hardcoded array literal on a gem-owned class (`Comment::ALLOWED_COMMENTABLES`,
`Report::ALLOWED_REPORTABLES`, etc.) forces the host-app developer into an error-prone
override/monkey-patch of engine code just to opt in, which fights the platform's core value
proposition as a "swiss army knife" foundation.

The existing `included_in_models` pattern (see below) already provides the dynamic-discovery
mechanism this calls for:

```ruby
def self.included_in_models
  included_module = self
  Rails.application.eager_load! unless Rails.env.production?
  ActiveRecord::Base.descendants.select { |model| model.include?(included_module) }
end
```

`SafeClassResolver`'s job — never `constantize` an attacker-supplied string unless
allow-listed — is unchanged by this. Only the *source of truth* for what's allow-listed
changes: from a manually-synced array that drifts out of sync with reality, to live
reflection of what's actually included.

## Part 1 — Existing `included_in_models` definitions (7, prior to this change)

All structurally identical (eager-load unless production, then
`ActiveRecord::Base.descendants.select { |m| m.include?(mod) }`), one line memoized:

| Concern | Consumer(s) |
|---|---|
| `Privacy` (`app/models/concerns/better_together/privacy.rb`) | `lib/tasks/data_migration.rake` |
| `HostsEvents` (`app/models/concerns/better_together/hosts_events.rb`) | `EventsController`, `_event_host_fields.html.erb` |
| `Invitable` (`app/models/concerns/better_together/invitable.rb`) | `InvitationsController` (feeds `SafeClassResolver.resolve!` — the existing precedent for exactly what this audit proposes doing more broadly) |
| `TrackedActivity` (`app/models/concerns/better_together/tracked_activity.rb`) | `lib/tasks/data_migration.rake` |
| `Metrics::Viewable` (`app/models/concerns/better_together/metrics/viewable.rb`) | `Metrics::PageViewsController` |
| `Joatu::Exchange` (`app/models/concerns/better_together/joatu/exchange.rb`, memoized with `@included_in_models ||=`) | `Joatu::JoatuController` |
| `Searchable` (`app/models/concerns/better_together/searchable.rb`) | `Search::Registry` |

`Invitable` is the closest existing precedent to what this audit converts: it already feeds
`included_in_models` straight into `SafeClassResolver.resolve!(allowed: ...)`, exactly the
shape being applied to `Commentable`, `Reportable`, `Shareable`, and `Shortlinkable` below.

## Part 2 — The 4 approved conversion candidates

### 1. `Comment::ALLOWED_COMMENTABLES` → `Commentable.included_in_models`

- Concern already exists: `app/models/concerns/better_together/commentable.rb`, currently
  included only by `Post`.
- Change: add `included_in_models` to `Commentable`; `Comment` drops the array constant and
  validates against `Commentable.included_in_models.map(&:name)` instead;
  `CommentsController`'s `resolve_commentable` (via `SafeClassResolver`) does the same.
- No other models change — this is purely mechanical since `Commentable` already has exactly
  one includer.

### 2. `Report::ALLOWED_REPORTABLES` → new `Reportable` concern + `included_in_models`

- No `Reportable` concern exists today. `ALLOWED_REPORTABLES` currently lists: `Person, Post,
  Event, Page, Community, Comment, Message, Upload, Content::Block, Joatu::Offer,
  Joatu::Request, Joatu::Agreement` (12 entries).
- Only `Person` and `Comment` currently declare an explicit `has_many :reports_received, as:
  :reportable` association inline; the other 10 models don't declare the inverse at all.
- Plan: new `Reportable` concern provides `has_many :reports_received, as: :reportable,
  class_name: 'BetterTogether::Report'` (no `dependent:`, matching the existing
  Report/Safety::Case-survives-deletion behavior already documented in `Comment`) plus
  `included_in_models`. Add `include Reportable` to all 12 models, removing the now-redundant
  inline `has_many :reports_received` from `Person` and `Comment`. `Report`, `ReportsController`,
  `FeedbackPolicy`, and `ContentActionsHelper` switch from the array constant to
  `Reportable.included_in_models.map(&:name)`.
- This is the largest of the 4 conversions (touches ~12 model files) but each touch is a
  single `include` line addition (or association swap for Person/Comment).

### 3. `Metrics::TrackShareJob::ALLOWED_SHAREABLES` → new `Shareable` concern + `included_in_models`

- No `Shareable` concern exists today. Current list: `Page, Event, Post, Community` (4 entries).
- Plan: new `Shareable` concern (marker-only — no association needed, since `Metrics::Share`
  already has its own polymorphic `belongs_to :shareable` and no inverse `has_many` is
  declared on the shared-content side today) plus `included_in_models`. Add `include
  Shareable` to Page/Event/Post/Community. `TrackShareJob` switches from the array constant
  to `Shareable.included_in_models.map(&:name)`.

### 4. `ShortLinksController::LINKABLE_TYPES` → `Shortlinkable.included_in_models`

- Concern already exists: `app/models/concerns/better_together/shortlinkable.rb`, included by
  `Post, Community, Event, Page` — confirmed exact 1:1 match with `LINKABLE_TYPES` today.
- Change: add `included_in_models` to `Shortlinkable`; controller switches from the hardcoded
  array to `Shortlinkable.included_in_models.map(&:name)`.
- Side fix bundled in: `ShortLinksController` currently does a bare
  `LINKABLE_TYPES.include?(type)` check followed by a raw `type.constantize`, unlike every
  other consumer in the codebase which routes through `BetterTogether::SafeClassResolver`.
  Switching to `SafeClassResolver.resolve!(type, allowed: Shortlinkable.included_in_models.map(&:name))`
  brings it in line with the established safe-resolution convention as part of this change.

## Part 3 — Array constants surveyed but NOT being converted (different axis, not a security concern)

These don't fit the "which models opt in via `include`" question at all, regardless of the
dynamic-extension-point philosophy above — converting them would answer a different question
than the one they're actually asking:

| Constant | What it actually encodes | Why `included_in_models` doesn't apply |
|---|---|---|
| `WizardStepsController::WIZARD_FORM_CLASSES` | Valid wizard-step form objects (`HostPlatformDetailsForm`, `HostPlatformAdminForm`) | Plain Ruby objects, not `ActiveRecord::Base` descendants — `included_in_models`'s descendant-scan is structurally inapplicable |
| `Authorship::AUTHOR_TYPES` (`Person`, `Robot`) | Who is eligible to *be* an author | Inverse relationship — Person/Robot don't `include` a mixin to *become* authorable; they're authors by identity. `Authorable` (the concern for things *that have* authors, e.g. `Post`) is a different axis entirely |
| `Resourceful::RESOURCE_CLASSES` | Valid resource types a `Role`/`ResourcePermission` can scope to (`Community, Platform, Person, Metrics, Metrics::Report`) | Nothing currently `include`s `Resourceful` — it's included by `Role`/`ResourcePermission` themselves, *about* these types, not by the types. Also includes a non-AR entry (`Metrics` module) |
| `NavigationItem::LINKABLE_CLASSES` (`Page` only) | Valid nav-item link targets | Single-element today; *could* become a `Linkable` concern if nav items should be host-app-extensible, but that's a separate, not-yet-requested design decision, not implied by the current single-item list |
| `Categorizable.allowed_category_classes` | Valid `Category`-like *target* classes (`Category, EventCategory, Joatu::Category`) a categorizable model's `category_class_name` may point to | Lives on a concern, but answers "what can I categorize *against*", not "who includes `Categorizable`" — opposite axis from `included_in_models` |
| `Content::BlocksController::ALLOWED_RESOURCE_SEARCH_CLASSES` (`Event, Checklist, Community, Person, Post`) | Resource-picker search scope for content blocks | Deliberately curated; diverges from any single concern's includer set (overlaps but doesn't match `Searchable.included_in_models`, which excludes Person and includes Page/Joatu::Request/Joatu::Offer/CallForInterest instead) |
| `Fleet::NodesController::ALLOWED_OWNER_TYPES` (`Community, Person`) | Polymorphic `Fleet::Node#owner` resolution | Implemented as a Hash (string → class), not fed through `SafeClassResolver`; not raised as one of the 4 approved candidates for this pass — worth a future look if fleet ownership becomes host-app-extensible |
| `PersonHardDeletionExecutor::DELETE_ONLY_CLASSES`/`MEMBERSHIP_MODELS`, `PersonHardDeletionInventory::DELETE_ONLY_MODELS` | Internal hard-deletion-pipeline classification (delete vs destroy) | Not a public extension point at all — internal business logic for one specific batch job. Two classes hold slightly-diverging copies of a similar list, which is its own (separate) code-health finding worth a follow-up look |

## Side findings (out of scope for this pass, flagged for follow-up)

- **Two competing `SafeClassResolver` implementations** are both on the Zeitwerk autoload
  path and both define `module BetterTogether::SafeClassResolver`:
  `lib/better_together/safe_class_resolver.rb` (accepts `Class` or `String` entries in
  `allowed:`) and `app/services/better_together/safe_class_resolver.rb` (string-only, its own
  `normalize_name`/`constantize_safely`). Which one actually wins at runtime depends on
  Zeitwerk's autoload-path resolution order, and the existing spec file even has a comment
  acknowledging the ambiguity (`# Explicitly load the file since it may not be autoloaded`).
  Worth resolving independently of this audit, since it's a correctness/security-adjacent
  question in its own right.
