# Navigation Area Management

This document describes how to reset and reseed navigation areas in the Better Together Community Engine.

## Overview

The NavigationBuilder provides methods to reset and reseed navigation areas without affecting pages. This is useful when you need to update navigation structure or fix navigation issues without losing page content.

## Available Rake Tasks

All tasks are under the `better_together:generate` namespace:

```bash
# List all navigation areas and items
bin/dc-run rails better_together:generate:list_navigation

# Reset all navigation areas (preserves pages)
bin/dc-run rails better_together:generate:reset_navigation

# Reset specific navigation area
bin/dc-run rails better_together:generate:reset_navigation_area[platform-header]

# Full rebuild (DESTRUCTIVE - deletes pages too!)
bin/dc-run rails better_together:generate:navigation_and_pages
```

## Detailed Methods

### 1. Reset All Navigation Areas

**Ruby Console:**
```ruby
BetterTogether::NavigationBuilder.reset_navigation_areas
```

**Rake Task:**
```bash
bin/dc-run rails better_together:generate:reset_navigation
```

**What it does:**
- Deletes all navigation items
- Deletes all navigation areas
- Rebuilds all four navigation areas:
  - Platform Header
  - Platform Host
  - Better Together
  - Platform Footer
- **Preserves all pages** (pages are not deleted)

### 2. Reset Specific Navigation Area

**Ruby Console:**
```ruby
BetterTogether::NavigationBuilder.reset_navigation_area('platform-header')
```

**Rake Task:**
```bash
bin/dc-run rails better_together:generate:reset_navigation_area[platform-header]
```

**Available slugs:**
- `platform-header` - Main navigation menu
- `platform-host` - Host admin dropdown menu
- `better-together` - Better Together dropdown
- `platform-footer` - Footer links

**What it does:**
- Deletes navigation items for the specified area
- Deletes the navigation area
- Rebuilds only that specific navigation area
- **Preserves all pages**

### 3. List Navigation Areas

**Rake Task:**
```bash
bin/dc-run rails better_together:generate:list_navigation
```

**What it does:**
- Shows all navigation areas with their details
- Lists all navigation items in each area
- Shows parent-child relationships
- Displays visibility and protection status

**Example output:**
```
Navigation Areas:
================================================================================

Area: Platform Header
  Slug: platform-header
  Visible: true
  Protected: true
  Items: 3
  Navigation Items:
    - About (link)
    - Events (link)
    - Exchange Hub (link)
...
```

### 4. Full Rebuild (Includes Pages)

**Rake Task:**
```bash
bin/dc-run rails better_together:generate:navigation_and_pages
```

**What it does:**
- Deletes all pages
- Deletes all navigation items
- Deletes all navigation areas
- Rebuilds everything from scratch
- **WARNING:** This deletes all pages including custom content

## Navigation Areas Structure

### Platform Header
- **Purpose:** Main site navigation at top of page
- **Contains:**
  - About page link
  - Events link (route-based)
  - Exchange Hub link (route-based)

### Platform Host
- **Purpose:** Admin/host management dropdown
- **Contains:**
  - Dashboard
  - Communities
  - Navigation Areas
  - Pages
  - People
  - Platforms
  - Roles
  - Resource Permissions

### Better Together
- **Purpose:** Information about the platform software
- **Contains:**
  - What is Better Together?
  - About the Community Engine

### Platform Footer
- **Purpose:** Footer links for policies and info
- **Contains:**
  - FAQ
  - Privacy Policy
  - Terms of Service
  - Code of Conduct
  - Accessibility
  - Cookie Policy
  - Code Contributor Agreement
  - Content Contributor Agreement
  - Contact

## Common Use Cases

### Update Navigation After Adding New Pages

If you've added new pages to footer_pages in NavigationBuilder:

```bash
# Reset just the footer area
bin/dc-run rails navigation:reset_area[platform-footer]
```

### Fix Broken Navigation

If navigation items are missing or duplicated:

```bash
# Reset all navigation areas
bin/dc-run rails navigation:reset
```

### Development: Fresh Start

For a completely fresh navigation setup:

```bash
# Full rebuild (careful - deletes pages!)
bin/dc-run rails navigation:rebuild
```

### Check Current Navigation State

```bash
# List all areas and items
bin/dc-run rails navigation:list
```

## Programmatic Usage

### In Seeds or Migrations

```ruby
# Reset all navigation (safe for pages)
BetterTogether::NavigationBuilder.reset_navigation_areas

# Reset specific area
BetterTogether::NavigationBuilder.reset_navigation_area('platform-footer')

# Full rebuild (destructive)
BetterTogether::NavigationBuilder.build(clear: true)
```

### In Rails Console

```ruby
# Reset navigation
BetterTogether::NavigationBuilder.reset_navigation_areas

# Check what areas exist
BetterTogether::NavigationArea.pluck(:name, :slug)

# See items in an area
area = BetterTogether::NavigationArea.find_by(slug: 'platform-footer')
area.navigation_items.pluck(:title, :item_type, :position)
```

## Important Notes

### Protected Records

All navigation areas and items created by the builder are marked as `protected: true`. This means:
- They cannot be deleted through the UI
- They are considered system records
- Manual database edits may be needed to modify protection status

### Localization

All navigation building happens within `I18n.with_locale(:en)`. If you need other locales:
- Pages support multi-locale attributes (title_en, title_es, etc.)
- Navigation items also support multi-locale attributes
- Update the builder methods to include additional locales

### Page Preservation

The `reset_navigation_areas` and `reset_navigation_area` methods preserve pages because:
- Pages may contain user-generated content
- Pages may have been customized
- Navigation can be rebuilt without affecting page content
- Pages are referenced by navigation items but not dependent on them

### Safe Order of Operations

When resetting navigation:
1. Child navigation items are deleted first
2. Parent navigation items are deleted second
3. Navigation areas are deleted last
4. This respects foreign key constraints

## Troubleshooting

### "Navigation area with slug 'X' not found"

The area doesn't exist. Check available slugs:
```ruby
BetterTogether::NavigationArea.pluck(:slug)
```

### Duplicate Navigation Items

Run a reset:
```bash
bin/dc-run rails navigation:reset
```

### Pages Missing After Reset

If you used `navigation:rebuild`, pages were deleted. Restore from backup or reseed:
```bash
bin/dc-run rails db:seed
```

### Permission Errors in UI

Navigation areas and items are protected. To modify through UI:
1. Unprotect in console: `area.update(protected: false)`
2. Make changes in UI
3. Re-protect: `area.update(protected: true)`

## Related Files

- Builder: `app/builders/better_together/navigation_builder.rb`
- Rake tasks: `lib/tasks/navigation.rake`
- Seeds: `db/seeds.rb`
- Models:
  - `app/models/better_together/navigation_area.rb`
  - `app/models/better_together/navigation_item.rb`
  - `app/models/better_together/page.rb`
