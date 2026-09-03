# Content block privacy & visibility — surface assessment (2026-09-02)

## Why this exists

`BetterTogether::Content::Block` includes `Privacy` (column, default `'private'`), but
**nothing consumes a block's `privacy` for visibility**. The only code that reads it is
0.11.0's `BetterTogether::ActiveStorageSecurity#authorize_blob_access` (#1392), which gates a
block's *attached media* (background/hero images) — not the block's rendered HTML, its API
representation, or search indexing.

Consequences seen in production (`newfoundlandlabrador.online`):

- A private hero block on a public homepage renders its heading/overlay/text to anonymous
  visitors (page render ignores block privacy) **but** its background image returns `401`
  (`authorize_blob_access` sees `record.privacy_public? == false`). Inconsistent.
- Editors have no UI to see or set block privacy — the column was added
  (`20241003180137_add_creator_privacy_and_visible_columns_to_better_together_content_blocks`)
  without a field in the block editor.

This PR adds the editor field + i18n and backfills sane values for public-page blocks
(`20260902190000`). **Making block privacy actually gate visibility is deliberately deferred to
a follow-up** — this document is the map for that work.

## Target behaviour (follow-up)

Block privacy should gate the block's visibility *within its page*, subject to the block
policy and the page's own privacy/publication state:

| block.privacy | who may see the block |
|---------------|-----------------------|
| `public`      | anyone who can see the page |
| `community`   | signed-in members of the page's community (or platform), plus editors |
| `private`     | editors / platform content managers only |

A block is never *more* visible than its page (page privacy + `published?` is the outer gate,
already enforced by `PagePolicy`). `authorize_blob_access` should delegate to the **same**
policy decision so media and markup agree.

## Surfaces (each needs a decision in the follow-up)

### 1. Page render — `pages_controller#show` + `pages/show.html.erb`

- `@content_blocks = @page.content_blocks.includes(...)` and `@page.hero_block` — **no privacy
  filter**. `show.html.erb:55` renders every block; `:65` renders the hero unconditionally.
- `Page#content_blocks` / `Page#hero_block` (`app/models/better_together/page.rb:107,111`) are
  plain `blocks.where(...)` scopes — no privacy filter.
- **Follow-up:** filter the collection through `BlockPolicy::Scope` (or a new
  `visible_to?(agent)` predicate) in the controller, keyed to the requesting agent. Keep
  editors seeing everything (with a visual "private/community" affordance) so the page-builder
  preview still works.

### 2. Fragment caches — the important one

`pages/show.html.erb`:
- **Outer:** `cache page_show_cache_key(@page)` — key includes `page_visibility_cache_context`
  = `nav_permission_cache_stamp` **or** `current_user&.cache_key_with_version || 'guest'`
  (`app/helpers/better_together/pages_helper.rb:60,75`). So the whole page-content fragment is
  already **viewer-bucketed**. If block filtering is added inside this fragment, the bucketing
  must distinguish "can see community/private blocks" from "cannot" — verify
  `nav_permission_cache_stamp` already does (it is role/permission-derived) and, if not, fold a
  block-visibility stamp into `page_visibility_cache_context`.
- **Inner hero cache:** `cache ['page-hero', @page.id, @page.hero_block&.updated_at,
  I18n.locale]` (`show.html.erb:64`) — **no viewer context**. If a hero can be
  non-public this leaks across viewers. Add the same visibility stamp, or drop this nested
  cache and rely on the outer one.
- **Per-block partial caches:** every block partial wraps itself in
  `cache block.cache_key_with_version` (or `[block, <content>, I18n.locale]`) — **no viewer
  context**. Safe today only because the block always renders identically. Once visibility is
  conditional, either (a) never cache a non-public block's partial, (b) add a visibility stamp,
  or (c) do the visibility gate *outside* every block partial (in the `show.html.erb` loop) so
  a hidden block's partial is simply not rendered/cached. Option (c) is cleanest.
- `PagesHelper#page_show_cache_key` ends with a manual `'v3'` version string — bump it when the
  fragment's contents-logic changes.

### 3. JSON:API

- `BlockResource` (`app/resources/better_together/api/v1/block_resource.rb`) exposes
  `identifier, privacy, visible, protected` + full content + `has_many :pages` + `filter
  :privacy`.
- `ApplicationResource.records` = `Pundit.policy_scope!(current_user, Content::Block)` →
  `Content::BlockPolicy::Scope#resolve` = `platform_scoped.includes(:pages)` — **no privacy
  filter**. `BlockPolicy#index?/show? == platform_content_manager?`, so the top-level
  `/api/v1/blocks` collection is admin-only at the action gate, but:
- `PageResource has_many :blocks, :page_blocks`. `GET /api/v1/pages/:id?include=blocks` loads
  related blocks through `BlockResource`'s scope (still unfiltered). A non-manager reading a
  public page via the API would receive its private blocks.
- **Follow-up:** add a privacy filter to `Content::BlockPolicy::Scope` (public always;
  community when the agent is a community/platform member; unrestricted for managers), and
  audit `PageBlockResource` / `PageResource` includes for the same.

### 4. Search indexing — `Page#as_indexed_json`

`app/models/better_together/page.rb:126` indexes
`content_blocks.filter_map { |block| indexed_block_text(block) }` and
`template_blocks.map { ... }` — **all block text regardless of privacy**. A private block's
markdown/rich-text becomes full-text searchable, and (depending on the search result view)
could surface a snippet to a non-member.
- **Follow-up:** `as_indexed_json` should only index `privacy_public?` blocks (community/private
  block text should not be in the shared index), or the search result renderer must re-check
  visibility per hit.

### 5. Media gate — `authorize_blob_access` (`ActiveStorageSecurity`)

Already privacy-aware, but only checks `blob.attachments.first.record.privacy_public?` — it
does **not** consider page publication/privacy, community membership, or the block policy, and
`enforce_download_policy!` is a no-op for blocks (`BlockPolicy` has no `download?`).
- **Follow-up:** give `Content::BlockPolicy` a `download?`/`show?` that encodes the table above
  and have `authorize_blob_access` call it, so a `community` hero image is served to members
  and the markup + media decisions always agree.

### 6. Contributor / editor preview

`pages_controller#show` + `content_actions_visible_for?` / `policy(@page).update?` — editors
get inline edit affordances. The block-visibility filter must **exempt** platform content
managers / page contributors so the builder and preview keep showing hidden blocks (with a
badge). `BadgesHelper#privacy_badge` already exists for this.

### 7. Not affected (confirmed)

- Sitemap (`Page#refresh_sitemap`) — lists page URLs, not block content; page privacy governs.
- Static-page ERB templates (`render template: @page.template`) — not DB blocks.
- `Content::Template` blocks (`template_blocks`) — indexed (see §4) but rendered from ERB
  partials, not user content; treat as always-public.

## Recommended follow-up PR shape

1. `Content::BlockPolicy`: add `show?` + `download?` (+ `Scope` privacy filter) per the table.
2. `Page#content_blocks` / `#hero_block`: accept an `agent:` and filter, **or** filter in
   `pages_controller#show` via `policy_scope` — keep model scopes unfiltered for the builder.
3. `pages/show.html.erb`: gate each block in the `.each` loop (option (c) above); remove/rework
   the nested `page-hero` cache; bump `page_show_cache_key`'s `'v3'`.
4. `authorize_blob_access`: delegate to `Content::BlockPolicy`.
5. `Page#as_indexed_json`: index only public blocks.
6. JSON:API: verify `BlockResource` / `PageResource` includes respect the new scope.
7. Specs: a matrix of {page privacy × block privacy × viewer (anon / member / manager)} for
   rendered HTML, the blob endpoint, the JSON:API page+include, and search payload.
