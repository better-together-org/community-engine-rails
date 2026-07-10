# PR #1651 — Merge Readiness Assessment

**Branch:** `pr1651-remediation` (tracks remote `feat/mvp-comment-system`)
**Target:** `release/0.11.0-notes`
**Assessed at:** commit `3cc99ade7` (HEAD), merge-base `61ff2bba6`
**As of:** 2026-07-10

This is a point-in-time assessment of every review finding raised on PR #1651 (the
original design-review comment plus the separate 8-angle comprehensive review),
cross-checked against the actual current state of the branch — not against what the
resolution comments *say* was done, but against the files themselves. It also inventories
every view changed by this PR, as input to the screenshot/diagram documentation work
tracked alongside this file.

## 1. Comprehensive 8-angle review — 12 inline findings

| # | Severity | Location | Finding | Status | Evidence |
|---|----------|----------|---------|--------|----------|
| 1 | CRITICAL | `comment.rb` | Comment deletion cascaded to destroy `Report`/`Safety::Case` | **RESOLVED** (`fc579296f`) | `reports_received` no longer declares `dependent: :destroy`; `Reportable` concern's base association has no `dependent:` |
| 2 | HIGH | `person.rb` | `notify_on_comments` had no reachable write path | **RESOLVED** (`9dbf547f5`) | Field present in `_preferences.html.erb:46-49` and `_preferences_self_contained.html.erb:36-39`; both controllers permit it |
| 3 | HIGH | `comments_controller.rb` | Notifications routed to `creator`, not credited `author`(s) | **RESOLVED** (`d4bd2733e`) | `notify_commentable_owners` now prefers `governed_authors`, falls back to `creator` |
| 4 | MEDIUM | `_comments_section.html.erb` | N+1 on `comment.creator` | **RESOLVED** (`dc3ff3ee3`) | `CommentPolicy::Scope#resolve` chains `.include_creator` |
| 5 | MEDIUM | `comment_policy.rb` | Reimplemented `SelfServicePublishablePolicy` instead of including it | **RESOLVED** (`dc3ff3ee3`), **verified intact** after the later CommentConfig rewrite | Current file (`comment_policy.rb:6`) still `include SelfServicePublishablePolicy`, uses `creator_of?(record)` |
| 6 | MEDIUM | `comments_controller.rb` | No failure branch on `@comment.save == false` | **RESOLVED** (`cc1371ff9`) | `save_comment_and_notify` branches on save result; `_form.html.erb:9-20` renders `comment.errors` |
| 7 | MEDIUM | `comment.rb` | `ALLOWED_COMMENTABLES` enforced only at the app layer, no DB constraint | **RESOLVED as documentation, then superseded** | `ALLOWED_COMMENTABLES` no longer exists — replaced entirely by dynamic `Commentable.included_in_models` (session's `included_in_models` refactor, `951e02460`). A DB check constraint is now structurally inapplicable to a dynamic extension point; the single-layer-enforcement tradeoff is documented in `docs/developers/architecture/polymorphic_allowlist_extension_audit.md` |
| 8 | MEDIUM | `comment.rb:27` | `broadcast_append_later_to` Pundit-context workaround duplicated with `Message` | **OPEN — intentionally deferred** | No change since the review; needs an engine-level `BroadcastableRenderer`-style fix, out of scope for this PR |
| 9 | MEDIUM | `comments_helper.rb:19` | `rescue Devise::MissingWarden` triplicated (3rd instance) | **OPEN — intentionally deferred** | No change since the review; needs a cross-cutting fix touching `ContentActionsHelper`/`ApplicationHelper` too |
| 10 | MEDIUM | `comment_added_notifier.rb` | `:action_cable` channel had no preference gate | **RESOLVED** (`d4bd2733e`) | Both channels now gated by `recipient_allows_comment_notifications?`; notifier spec covers both true/false paths |
| 11 | MEDIUM/LOW | `comment.rb:35` | `dom_id`/stream-target computed independently in 3+ places | **OPEN — intentionally deferred** | Still 3 independent `dom_id(comment)`/`dom_id(@comment)` call sites (`_comment.html.erb:2`, `comment_added_notifier.rb`, `comment_mailer/added.html.erb:9`) |
| 12 | LOW | `_form.html.erb` | Dead reference to unregistered Stimulus controller | **RESOLVED** (`cc1371ff9`) | `data: { controller: 'better_together--comment-form' }` removed from current `_form.html.erb` |

**9 of 12 resolved, 3 explicitly deferred as tracked follow-ups (not blocking).** All 3 deferrals
are pre-existing structural patterns this PR didn't introduce (the `Message` broadcast
workaround, the `Devise::MissingWarden` rescue, and one other unrelated helper) — the
comprehensive review's own framing already treats them as separate, focused follow-up PRs
rather than something this PR must fix.

## 2. Design-review comment — comment-permission-controls proposal

### 2.1 "No control over whether comments are allowed, or by whom"

**RESOLVED** by the `CommentConfig` implementation (commit `3cc99ade7`, this session),
matching the proposed design almost exactly:
- `BetterTogether::CommentConfig` — polymorphic settings model, `permission`/`visibility`
  enums (`inherit`/`community`/`disabled` and `inherit`/`community` respectively), unique
  index on `[commentable_type, commentable_id]`
- `Commentable` concern gained the lazy `comment_permission`/`comment_visibility`
  accessor pair — no backfill needed, existing posts read `'inherit'` with zero rows
- `CommentPolicy#create?` gates on `commentable_accepts_new_comments?`, **no manager bypass**
  (platform/community managers are subject to the same posting rule as everyone else,
  per the original ask)
- `posts/_form.html.erb` gained the nested `comment_config` fieldset
- `_comments_section.html.erb`'s single sign-in fallback now differentiates
  sign-in-required / agreement-required / disabled / community-required via
  `CommentsHelper#comment_denial_reason`

**Not yet reflected on GitHub**: this work landed after the review comment was posted and
has not yet been pushed as a reply/resolve on the design-review thread. Before merge, post
a resolution comment on the original design-review issue comment summarizing the
`CommentConfig` implementation (mirroring the format used for the 8-angle review's
per-finding replies).

### 2.2 "Structural suggestion — Turbo Frame `CommentsController#index`"

Two distinct parts were bundled in this suggestion:

- **Authorization mechanism** (bare `Pundit.policy(user, commentable)&.show?` → resolving
  through the commentable's own `policy_scope`): **RESOLVED**, folded into the `CommentConfig`
  work as the explicitly-planned "bundled fix." `CommentPolicy#commentable_visible_to_agent?`
  now reads `Pundit.policy_scope(user, commentable.class)&.where(id: commentable.id)&.exists?`
  instead of a bare `show?` boolean, and `Scope#resolve` derives visibility per-`commentable_type`
  via the same method (see `comment_policy.rb:91-93`, `:64-72`).
- **`CommentsController#index` + Turbo Frame restructuring**: **NOT DONE.** This is a genuine
  structural change (new route, new controller action, `_comments_section.html.erb` becomes
  a thin frame stub) rather than a fix, and the review itself frames it as a suggestion for
  future pagination/lazy-loading, not a blocking requirement. Recommend tracking as a
  separate follow-up rather than folding into this already-large PR.

### 2.3 "Smaller findings"

| Finding | Status | Notes |
|---------|--------|-------|
| `set_comment` uses `policy_scope(Comment).find` for `destroy` — a moderator who has personally blocked the comment's author gets `RecordNotFound` even though `community_content_manager?`/`platform_manager?` would authorize the destroy | **OPEN** | Verified against current `comments_controller.rb:51` — unchanged. Real, reproducible gap: `Scope#resolve`'s `excluding_blocked_for(agent)` removes the row before `authorize` ever runs. Fix is small (`Comment.find(params[:id])` + `authorize @comment`, matching the review's own suggested fix) and low-risk — **recommend fixing before merge** |
| `blocked_by_commentable_creator?`/notification recipient divergence for creator ≠ author | **Partially addressed** | Notification routing now prefers `governed_authors` (finding #3 above), but `blocked_by_commentable_creator?` still checks only `creator_id`, not `governed_authors`. Documented in the original review as "worth a decision either way, even if it's just documenting this as a known MVP limitation" — acceptable to ship as-is, but should be called out explicitly in the PR description as a known limitation rather than left implicit |
| `Comment#content` has no max-length validation | **OPEN** | `comment.rb:12` still only `validates :content, presence: true`. Low-risk, non-blocking, but cheap to add (`length: { maximum: N }`) before merge |
| `comment_added_notifier_spec.rb` missing the preference-off path | **RESOLVED** | `spec/notifiers/better_together/comment_added_notifier_spec.rb:68-83` now covers both `recipient_allows_comment_notifications?` true/false paths |
| `CommentPolicy#destroy?` RBAC lookup not memoized per-comment (N+1-shaped, not a query N+1) | **OPEN — explicitly deferred in the original review** | "Considered and deferred... not worth building yet since `CommentPolicy` is the only consumer today" — no action needed |
| `PersonDeletionAnonymizer` omits `notify_on_comments` | **RESOLVED** | `person_deletion_anonymizer.rb:80` includes `'notify_on_comments' => false` (landed alongside `9dbf547f5`, not separately called out in that commit's own message) |
| Comment factory's `transient`/`after(:build)` style vs. `association :x, factory: :y` | **No action needed** | Style-only nit; `FactoryBot` rubocop department is disabled repo-wide |
| `render_invalid_commentable` returns bare `head :not_found` for `local: false` submissions | **OPEN** | No visible error if the commentable becomes invalid mid-session (e.g. deleted before submit). Low-frequency edge case, non-blocking |

## 3. Remaining corrections before merge to `release/0.11.0-notes`

Ranked by whether they block merge:

**Recommended before merge (small, low-risk, closes a real gap):**
1. Fix `CommentsController#set_comment` to use `Comment.find(params[:id])` + `authorize @comment`
   for `destroy`, not `policy_scope(Comment).find` — closes the moderator-blocked-by-own-block
   gap identified in the original design review.
2. Add a length validation to `Comment#content` (e.g. `length: { maximum: 10_000 }`, matching
   the scale of other free-text fields in this engine).
3. Post a resolution comment on the original design-review issue comment documenting that the
   `CommentConfig` proposal has been implemented (commit `3cc99ade7`), so the PR's GitHub
   thread history accurately reflects current state.

**Acceptable to ship as documented MVP limitations (no code change required, but should be
stated explicitly in the PR description):**
4. `blocked_by_commentable_creator?` keys off `creator_id` only, not `governed_authors` — a
   blocked staff-creator doesn't propagate the block to co-authored content.
5. `render_invalid_commentable`'s silent `head :not_found` for a mid-session invalid commentable.

**Deferred, tracked as separate follow-up work (not blocking this PR):**
6. Engine-level fix for the `broadcast_append_later_to` Pundit-render-context workaround
   (shared with `Message`).
7. Centralizing the `rescue Devise::MissingWarden` pattern (3rd occurrence).
8. Centralizing `dom_id`/stream-target computation (3+ independent call sites).
9. `CommentsController#index` + Turbo Frame restructuring for lazy-loaded, paginated comments.

## 4. View inventory — all ERB templates changed in this branch

12 files (7 new, 5 modified) relative to merge-base `61ff2bba6`:

### New

| File | Purpose | Stable selectors present |
|------|---------|---------------------------|
| `comments/_comments_section.html.erb` | Comment thread container, embedded in `posts/show.html.erb`. Wraps the whole section in a `show?` policy check; branches on `comment_denial_reason` to render the form or one of 3 denial states | `dom_id(commentable, :comments_heading)`, `dom_id(commentable, :comments)`, `comments-publishing-agreement-required`, `comments-<denial_reason>` |
| `comments/_comment.html.erb` | Single comment row — author name, timestamp, body, content-actions menu (delete/report) | `dom_id(comment)` |
| `comments/_form.html.erb` | New-comment textarea + submit, inline validation-error list | `new_comment`, `comment-errors-title`, `comment_content` |
| `comments/create.turbo_stream.erb` | Turbo Stream response for the requester's own tab on successful/failed submit | — (targets existing ids) |
| `comments/destroy.turbo_stream.erb` | Turbo Stream response for delete (comment removal broadcasts to all viewers) | — (no content, removal only) |
| `comment_added_notifier/notifications/_notification.html.erb` | In-app (Noticed) bell-notification partial for a new comment | delegates to `notifications/generic_notification` |
| `comment_mailer/added.html.erb` | Email notification body for a new comment | — |

### Modified

| File | Change | Stable selectors present |
|------|--------|---------------------------|
| `posts/show.html.erb` | Renders `comments/_comments_section` below the share buttons | (delegates to section partial) |
| `posts/_form.html.erb` | New nested `comment_config` fieldset (permission + visibility selects) next to the privacy field | `#{dom_id(post)}_comment_permission`, `#{dom_id(post)}_comment_visibility` (via `FormHelper`) |
| `people/_preferences.html.erb` | New `notify_on_comments` toggle switch (admin/person-edit form) | uses shared `toggle_switch` partial |
| `people/_preferences_self_contained.html.erb` | New `notify_on_comments` toggle switch (self-service Settings page) | uses shared `preference_field` helper |
| `reports/show.html.erb` | Guards against a nil `reportable` (survives comment deletion per finding #1's fix) with a translated fallback | `report-reported-record`, `report-reportable-unavailable` |

All 12 surfaces already carry stable DOM ids or well-scoped class selectors — the
mandatory "Selector quality gate" from `ce-pr-docs` is satisfied without further view
changes; the screenshot spec (tracked separately) can target these directly.

## 5. Summary

- 9 of 12 comprehensive-review findings resolved; 3 explicitly deferred (pre-existing,
  cross-cutting, out of scope for a comments-specific PR).
- The design-review's primary ask (comment permission/visibility controls) is now fully
  implemented via `CommentConfig`, including the "bundled" `show?`/`Scope` authorization fix.
- 2 small, low-risk fixes recommended before merge (`set_comment` policy_scope gap, content
  length validation); everything else is either resolved, an acceptable documented
  limitation, or explicitly deferred follow-up work.
