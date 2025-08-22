# Building a Page Sidebar Navigation (Admin Guide)

This short guide explains how to set up a Page‑specific sidebar navigation area and wire it to published pages.

## Overview
- Navigation Area: container for ordered, multi‑level navigation items.
- Navigation Items: each links to a Page, route, or URL; can nest for sections.
- Page: optionally references a `sidebar_nav` NavigationArea.

## Steps
1) Create a Navigation Area
- Go to Host Dashboard → Navigation Areas → New.
- Set `identifier` (e.g., `docs-sidebar`) and `visible: true`.

2) Add Navigation Items
- From the area page, add items:
  - For a Page link: set `item_type: link`, choose Linkable = Page (published pages only appear if published_at <= now), leave URL empty.
  - For an external/internal URL: set `item_type: link`, set `route_name` or `url`.
  - For grouping: set `item_type: dropdown` and add child items beneath it.
- Ordering: use position controls (or drag/drop if available) to arrange items.
- Visibility:
  - Page‑backed links auto‑hide until the Page is published.
  - Non‑page links use the `visible` flag.

3) Assign Sidebar to a Page
- Edit the target Page.
- In the Page form, set `Sidebar nav` to the area you created (`docs-sidebar`).
- Choose a layout that renders the sidebar (e.g., `page_with_nav`) if applicable.

4) Verify Rendering
- Visit the Page route (slugged URL).
- Sidebar renders as an accordion, automatically expanding the branch containing the current page.

## Caching Notes
- Sidebar cache key: `['sidebar_nav', nav.cache_key_with_version, "page-<id>"]`.
- Cache invalidates when the NavigationArea or any NavigationItem changes (`touch: true`), or when the Page updates.
- Ensure items preload translations and linkable translations to avoid N+1 queries.

## Tips
- Use dropdowns for section headings; nest items for hierarchy.
- Prefer Page links for auto‑visibility (published_at) and localization.
- Use route_name for app routes (e.g., `pages_url`, `hub_url`) when linking to internal sections outside the Pages system.
