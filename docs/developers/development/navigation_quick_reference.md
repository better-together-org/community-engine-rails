# Navigation Reset Quick Reference

## Quick Commands

```bash
# List all navigation areas and items
bin/dc-run rails better_together:generate:list_navigation

# Reset all navigation areas (safe - preserves pages)
bin/dc-run rails better_together:generate:reset_navigation

# Reset specific navigation area
bin/dc-run rails better_together:generate:reset_navigation_area[platform-header]
bin/dc-run rails better_together:generate:reset_navigation_area[platform-host]
bin/dc-run rails better_together:generate:reset_navigation_area[better-together]
bin/dc-run rails better_together:generate:reset_navigation_area[platform-footer]

# Full rebuild (DESTRUCTIVE - deletes pages too!)
bin/dc-run rails better_together:generate:navigation_and_pages
```

## Ruby Console

```ruby
# Reset all navigation areas
BetterTogether::NavigationBuilder.reset_navigation_areas

# Reset specific area
BetterTogether::NavigationBuilder.reset_navigation_area('platform-footer')

# Full rebuild
BetterTogether::NavigationBuilder.build(clear: true)

# Manual checks
BetterTogether::NavigationArea.count
BetterTogether::NavigationItem.count
BetterTogether::Page.count
```

## Navigation Area Slugs

- `platform-header` - Top navigation menu
- `platform-host` - Host/admin dropdown  
- `better-together` - Software info dropdown
- `platform-footer` - Footer links

## Safety Levels

✅ **Safe** (preserves pages):
- `better_together:generate:reset_navigation`
- `better_together:generate:reset_navigation_area[slug]`
- `better_together:generate:list_navigation`
- `reset_navigation_areas` (Ruby method)
- `reset_navigation_area(slug)` (Ruby method)

⚠️ **Destructive** (deletes pages):
- `better_together:generate:navigation_and_pages`
- `NavigationBuilder.build(clear: true)` (Ruby method)
