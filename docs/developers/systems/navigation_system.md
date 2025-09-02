# Navigation System

Explains Navigation Areas and Items, how they relate to Pages, and visibility + caching.

## Navigation Areas
- Model: `BetterTogether::NavigationArea`
- Purpose: named lists of ordered multi-level navigation items.
- Traits: Identifier, Protected, Visible (boolean `visible` + scope).
- Translations: `name`.
- Associations:
  - `has_many :navigation_items`
  - `belongs_to :navigable, polymorphic, optional` (used by Page sidebar nav)
- Common areas (by `identifier`):
  - `better-together` (product header)
  - `platform-header`, `platform-footer`, `platform-host`
  - Page-specific `sidebar_nav` (per Page)

## Navigation Items
- Model: `BetterTogether::NavigationItem`
- Purpose: link or dropdown nodes; nested via parent/children.
- Traits: Identifier, Positioned, Protected.
- Associations: `belongs_to :navigation_area`, `belongs_to :linkable, polymorphic, optional`
- Link types:
  - `link` with `linkable` (e.g., Page) or explicit `route_name`/`url`
  - `dropdown` with child items
- Visibility:
  - For `linkable` Page items, `visible` delegates to `linkable.published?` (enforces published_at before appearing).
  - For others, uses stored boolean `visible`.
  - Helpers fetch areas via `NavigationArea.visible`.
- URL resolution:
  - If `linkable` present → `linkable.url`
  - Else if `route_name` set → resolves via Rails/Engine URL helpers
  - Else fallback to stored `url` or `#identifier`

## Sidebar Navigation (Page)
- `Page` optionally references a `sidebar_nav` NavigationArea.
- Sidebar is rendered as an accordion; active page auto-expands branch.
- Visibility of sidebar items follows the same rules (Page‐backed items must be published).

## Caching
- Header/footer/header-host navs cached by nav area cache key:
  - `Rails.cache.fetch(['nav_area_items', nav.cache_key_with_version]) { render ... }`
- Sidebar nav cached by area + current page id:
  - `Rails.cache.fetch(['sidebar_nav', nav.cache_key_with_version, "page-#{current_page.id}"])`
- Items include translations and linkable translations in preloads to avoid N+1.
- NavigationAreas and Items `touch` relationships ensure cache keys change when items or parents update.

