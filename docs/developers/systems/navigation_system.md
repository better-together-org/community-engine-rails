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

## Route names for navigation items

An item can point at a named route instead of a URL. The picker in the item form lists the names in groups (public pages, host dashboard, safety, geography, Joatu, billing management, billing for members, and any group a host app adds), and the stored value is the route helper, for example `billing_plans_url`.

- The built-in names and their groups are `NavigationItem::ROUTE_NAME_GROUPS`. Each name resolves to the `<name>_url` helper.
- `NavigationItem.route_names` stays a flat `name => helper` hash. Validation, stored values and availability checks read it, so it keeps working for host apps that assign it directly.
- A host app adds its own names with `NavigationItem.register_route_names`, for example from the `included` block of its navigation item concern:

  ```ruby
  BetterTogether::NavigationItem.register_route_names(%i[venues tours], group: :venues)
  ```

  Names added without a group (`self.route_names = route_names.merge(...)`) are shown under "Other".
- Labels: every name needs `better_together.navigation_items.route_names.<name>` and every group `better_together.navigation_items.route_groups.<group>` in each locale. A host app's own names and groups show humanized until it translates them. `spec/i18n/navigation_route_names_spec.rb` enforces both lists for the gem's own names.
- A name whose page is only reachable in some states (billing switched on, host platform only) is hidden from the navigation when unavailable, through `NavigationItem::ROUTE_AVAILABILITY`. Keep an entry there in step with the target controller's own gate.

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

