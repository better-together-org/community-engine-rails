# Navigation Item Permissions MVP - Design Specification

**Date:** December 19, 2025  
**Status:** Design Phase  
**Priority:** High  
**Estimated Effort:** 8-12 hours

## Problem Statement

Navigation items currently only check `visible?` flag, with no runtime permission checking. This means:
- All authenticated users see the same navigation, regardless of their permissions
- No way to conditionally show/hide nav items based on user roles or permissions
- Security relies entirely on controller-level authorization (good defense-in-depth, but poor UX)

Users without access to certain features should not see navigation links to those features.

## MVP Goals

Create a flexible, extensible system for controlling navigation item visibility based on:
1. **Permission identifiers** - Link nav items to specific resource permissions
2. **Policy checks** - Use Pundit policies for complex authorization logic
3. **Custom visibility rules** - Support lambda/proc-based visibility logic for edge cases
4. **Backward compatibility** - Existing nav items continue working without changes

## Design Overview

### 1. Database Schema Changes

Add Privacy concern and permission configuration to navigation items:

```ruby
# Migration: AddPrivacyAndPermissionsToNavigationItems
class AddPrivacyAndPermissionsToNavigationItems < ActiveRecord::Migration[7.1]
  def change
    change_table :better_together_navigation_items do |t|
      # Add privacy column using bt_ helper (defaults to 'private' like all BT models)
      t.bt_privacy
      
      # Simple permission identifier check (e.g., 'view_metrics_dashboard')
      # Only used when privacy is not 'public'
      t.string :permission_identifier
      
      # Visibility strategy: 'permission', 'authenticated'
      # Only shown in UI when privacy is not 'public'
      # Defaults to 'authenticated' for backward compatibility
      t.string :visibility_strategy, default: 'authenticated', null: false
    end
    
    add_index :better_together_navigation_items, :permission_identifier
    add_index :better_together_navigation_items, :visibility_strategy
    add_index :better_together_navigation_items, :privacy
    
    # Run rake task to set existing nav items to public for backward compatibility
    reversible do |dir|
      dir.up do
        # This will be executed by the rake task called from migration
        puts "Running rake task to update existing navigation item privacy..."
        Rake::Task['better_together:navigation_items:set_public_privacy'].invoke
      end
    end
  end
end
```

### 2. Data Migration Rake Task

Create a rake task to set existing navigation items to public:

```ruby
# lib/tasks/better_together/navigation_items.rake
namespace :better_together do
  namespace :navigation_items do
    desc 'Set privacy to public for existing visible navigation items'
    task set_public_privacy: :environment do
      puts "Updating existing navigation items privacy settings..."
      
      # Count for reporting
      updated_count = 0
      skipped_count = 0
      
      BetterTogether::NavigationItem.find_each do |nav_item|
        # Only update items that don't already have privacy set (will be 'private' default)
        # Check if item is/should be visible
        if should_be_public?(nav_item)
          nav_item.update_column(:privacy, 'public')
          updated_count += 1
        else
          # Keep as private but mark we processed it
          skipped_count += 1
        end
      end
      
      puts "Updated #{updated_count} navigation items to public"
      puts "Skipped #{skipped_count} navigation items (keeping private)"
      puts "Done!"
    end
    
    private
    
    def should_be_public?(nav_item)
      # If the visible boolean is true, make it public
      return true if nav_item.visible == true
      
      # If linked to a published page, make it public
      if nav_item.linkable_type == 'BetterTogether::Page' && nav_item.linkable.present?
        return nav_item.linkable.published?
      end
      
      # Default: if visible flag is true, make it public for backward compatibility
      nav_item.visible == true
    end
  end
end
```

### 3. Model Implementation

```ruby
# app/models/better_together/navigation_item.rb
module BetterTogether
  class NavigationItem < ApplicationRecord
    include Identifier
    include Positioned
    include Protected
    include Privacy  # NEW: Add Privacy concern
    
    # Visibility strategies - only implement what we need now
    VISIBILITY_STRATEGIES = %w[
      authenticated
      permission
    ].freeze
    
    validates :visibility_strategy, inclusion: { in: VISIBILITY_STRATEGIES }
    validates :permission_identifier, presence: true, if: -> { visibility_strategy == 'permission' }
    
    # Validate that visibility_strategy is only set when privacy is not public
    validate :visibility_strategy_requires_non_public_privacy
    
    # Check if navigation item is visible to a specific user
    # @param user [User] The user to check visibility for
    # @param context [Hash] Additional context (platform, community, etc.)
    # @return [Boolean]
    def visible_to?(user, context = {})
      return false unless visible? # Check base visibility flag first
      
      # Public items are visible to everyone
      return true if public?
      
      # Non-public items require a user
      return false unless user.present?
      
      # For private/protected items, check visibility strategy
      case visibility_strategy
      when 'authenticated'
        true # User is authenticated (already checked above)
      when 'permission'
        check_permission_visibility(user, context)
      else
        false # Fail closed for unknown strategies
      end
    end
    
    private
    
    def visibility_strategy_requires_non_public_privacy
      return if privacy != 'public'
      return if visibility_strategy == 'authenticated' # Default is OK
      
      if permission_identifier.present?
        errors.add(:permission_identifier, 'cannot be set when privacy is public')
      end
    end
    
    def check_permission_visibility(user, context)
      return false unless permission_identifier.present?
      
      platform = context[:platform] || BetterTogether::Platform.find_by(host: true)
      return false unless platform
      
      user.permitted_to?(permission_identifier, platform)
    end
  end
end
```

### 4. Helper Method Updates

```ruby
# app/helpers/better_together/navigation_items_helper.rb
module BetterTogether
  module NavigationItemsHelper
    # Filter navigation items based on current user's permissions
    def visible_navigation_items(navigation_items, user: current_user, context: {})
      return [] unless navigation_items.present?
      
      context = context.merge(
        platform: context[:platform] || host_platform,
        community: context[:community] || host_community
      )
      
      navigation_items.select do |item|
        item.visible_to?(user, context)
      end
    end
    
    # Recursive filtering for nav items with children
    def visible_navigation_items_with_children(navigation_items, user: current_user, context: {})
      visible_items = visible_navigation_items(navigation_items, user: user, context: context)
      
      visible_items.map do |item|
        if item.children.any?
          # Recursively filter children
          visible_children = visible_navigation_items_with_children(
            item.children, 
            user: user, 
            context: context
          )
          
          # Only show parent dropdown if it has visible children
          next unless visible_children.any?
        end
        
        item
      end.compact
    end
  end
end
```

### 5. View Updates

Update navigation partials to use permission filtering:

```erb
<!-- app/views/better_together/navigation_items/_navigation_items.html.erb -->
<%# locals: (navigation_items:, navigation_area: navigation_items.first&.navigation_area, justify: 'center') %>

<% filtered_items = visible_navigation_items_with_children(navigation_items) %>

<% if filtered_items.any? %>
  <%= content_tag :ul, class: "navbar-nav flex-row flex-wrap justify-content-#{justify} #{dom_class(navigation_area, :nav_items)}", id: dom_id(navigation_area, :nav_items) do %>
    <%= render partial: 'better_together/navigation_items/navigation_item',
               collection: filtered_items, as: :navigation_item %>
  <% end %>
<% end %>
```

```erb
<!-- app/views/better_together/navigation_items/_navigation_item.html.erb -->
<%# locals: (navigation_item:, level: 0) %>

<% if navigation_item.visible_to?(current_user, platform: host_platform) %>
  <li id="<%= dom_id(navigation_item) %>" class="nav-item <%= 'dropdown' if navigation_item.children? %>">
    <%= link_to navigation_item.title, sanitize_url(navigation_item.url),
                class: nav_link_classes(navigation_item,
                  path: (
                    params[:path] ||
                    (url_for(
                      controller: params[:controller],
                      action: params[:action]
                    ) if params[:controller].present?)
                  )
                ),
                id: dropdown_id(navigation_item),
                role: dropdown_role(navigation_item),
                data: dropdown_data_attributes(navigation_item) %>

    <% if navigation_item.children? %>
      <%= render partial: 'better_together/navigation_items/navigation_dropdown_items',
                locals: { navigation_item:, level: level += 1} %>
    <% end %>
  </li>
<% end %>
```

### 6. Navigation Builder Updates

Update the navigation builder to set privacy and permission strategies:

```ruby
# app/builders/better_together/navigation_builder.rb
def build_host
  I18n.with_locale(:en) do
    area = ::BetterTogether::NavigationArea.create! do |area|
      area.name = 'Platform Host'
      area.slug = 'platform-host'
      area.visible = true
      area.protected = true
    end

    host_nav = area.navigation_items.create!(
      title_en: 'Host',
      slug_en: 'host-nav',
      position: 0,
      visible: true,
      protected: true,
      item_type: 'dropdown',
      url: '#',
      privacy: 'private',  # Not public - requires authentication
      visibility_strategy: 'authenticated'
    )

    host_nav_children = [
      {
        title_en: 'Dashboard',
        slug_en: 'host-dashboard',
        position: 0,
        item_type: 'link',
        route_name: 'host_dashboard_url',
        privacy: 'private',
        visibility_strategy: 'permission',
        permission_identifier: 'manage_platform'
      },
      {
        title_en: 'Analytics',
        slug_en: 'analytics',
        position: 1,
        item_type: 'link',
        route_name: 'metrics_reports_url',
        icon: 'chart-line',
        privacy: 'private',
        visibility_strategy: 'permission',
        permission_identifier: 'view_metrics_dashboard'
      },
      {
        title_en: 'Communities',
        slug_en: 'communities',
        position: 2,
        item_type: 'link',
        route_name: 'communities_url',
        privacy: 'private',
        visibility_strategy: 'permission',
        permission_identifier: 'manage_platform'
      },
      # ... other items with appropriate privacy and strategies
    ]
    
    # ... rest of implementation
  end
end
```

### 6. Caching Strategy

Since permission checks can be expensive, implement smart caching:

```ruby
# app/helpers/better_together/navigation_items_helper.rb
def platform_host_nav_items
  cache_key = [
    'platform_host_nav_items',
    platform_host_nav_area&.cache_key_with_version,
    current_user&.cache_key_with_version,
    current_locale
  ].compact.join('/')
  
  Rails.cache.fetch(cache_key, expires_in: 12.hours) do
    Mobility.with_locale(current_locale) do
      items = platform_host_nav_area&.top_level_nav_items_includes_children || []
      visible_navigation_items_with_children(items)
    end
  end
end
```

## Implementation Checklist

### Phase 1: Database & Model (3-4 hours)
- [ ] Create migration using `bt_privacy` helper (defaults to 'private')
- [ ] Create rake task to set existing nav items to public based on visible flag
- [ ] Add rake task invocation to migration (reversible block)
- [ ] Add Privacy concern to NavigationItem model
- [ ] Add validations for visibility_strategy
- [ ] Add validation preventing permission_identifier when privacy is public
- [ ] Implement `visible_to?` method with privacy checks
- [ ] Implement `check_permission_visibility` method
- [ ] Write model specs for privacy integration
- [ ] Write model specs for both visibility strategies (authenticated, permission)
- [ ] Test rake task with sample data

### Phase 2: Form & UI Updates (2-3 hours)
- [ ] Add privacy field to navigation item form
- [ ] Add visibility_strategy select field (hidden by default)
- [ ] Add permission_identifier field (hidden by default)
- [ ] Use dependent_fields Stimulus controller to show/hide visibility fields based on privacy
- [ ] Update form to only show visibility_strategy when privacy != 'public'
- [ ] Update form to only show permission_identifier when visibility_strategy == 'permission'
- [ ] Add helpful form labels and hints
- [ ] Write system specs for form interactions

### Phase 3: Helper & View Updates (1-2 hours)
- [ ] Update `visible_navigation_items` helper method
- [ ] Update `visible_navigation_items_with_children` helper method
- [ ] Update `_navigation_items.html.erb` partial
- [ ] Update `_navigation_item.html.erb` partial
- [ ] Update `_navigation_dropdown_items.html.erb` partial
- [ ] Add caching to helper methods
- [ ] Write helper specs

### Phase 4: Navigation Builder Updates (2-3 hours)
- [ ] Update `build_host` method with privacy and visibility strategies
- [ ] Set Analytics nav item to use privacy='private' + permission strategy
- [ ] Update all platform management nav items
- [ ] Update public nav items to use privacy='public'
- [ ] Test navigation builder seed data
- [ ] Write builder specs

### Phase 5: Testing & Documentation (1-2 hours)
- [ ] Write integration tests for permission-based filtering
- [ ] Test with different user roles (platform_manager, analytics_viewer, regular_user)
- [ ] Test caching behavior
- [ ] Test backward compatibility (existing nav items get default values)
- [ ] Update navigation documentation
- [ ] Add usage examples to README

## Usage Examples

### Example 1: Public Navigation (Default for existing items)
```ruby
# Navigation item visible to everyone
# After migration, existing visible nav items will have privacy='public'
nav_item = NavigationItem.create!(
  title: 'About',
  route_name: 'about_url',
  privacy: 'public'  # Explicitly set for new items that should be public
)
# No need to set visibility_strategy for public items (ignored)
```

### Example 2: New Items Default to Private
```ruby
# Navigation item only visible to logged-in users
nav_item = NavigationItem.create!(
  title: 'My Profile',
  route_name: 'profile_url',
  privacy: 'private',
  visibility_strategy: 'authenticated'
)
```

### Example 3: Authenticated Only (Explicit)
```ruby
# Navigation item only visible to logged-in users
nav_item = NavigationItem.create!(
  title: 'My Profile',
  route_name: 'profile_url',
  privacy: 'private',
  visibility_strategy: 'authenticated'
)
```

### Example 4: Permission-Based Visibility
```ruby
# Navigation item only visible to users with specific permission
nav_item = NavigationItem.create!(
  title: 'Analytics',
  route_name: 'metrics_reports_url',
  privacy: 'private',
  visibility_strategy: 'permission',
  permission_identifier: 'view_metrics_dashboard'
)
```

### Example 5: Platform Management Item
```ruby
# Navigation item for platform managers only
nav_item = NavigationItem.create!(
  title: 'Host Dashboard',
  route_name: 'host_dashboard_url',
  privacy: 'private',
  visibility_strategy: 'permission',
  permission_identifier: 'manage_platform'
)
```

### 7. Form UI Implementation

Update the navigation item form to use dependent_fields Stimulus controller:

```erb
<!-- app/views/better_together/navigation_items/_form.html.erb -->

<%= form_with(model: [:better_together, navigation_area, navigation_item], 
              data: { controller: 'dependent-fields' }) do |f| %>
  
  <!-- Existing fields: title, slug, url, etc. -->
  
  <!-- Privacy field - controls visibility of dependent fields -->
  <div class="mb-3">
    <%= f.label :privacy, class: 'form-label' %>
    <%= f.select :privacy, 
                 BetterTogether::NavigationItem::PRIVACY_OPTIONS.map { |p| [t("privacy.#{p}"), p] },
                 { include_blank: false },
                 class: 'form-select',
                 data: { 
                   dependent_fields_trigger_param: 'privacy',
                   action: 'change->dependent-fields#toggle'
                 } %>
    <div class="form-text">
      <%= t('.privacy_hint') %>
    </div>
  </div>

  <!-- Visibility Strategy - Only shown when privacy != 'public' -->
  <div class="mb-3"
       data-dependent-fields-target="field"
       data-dependent-fields-dependency="privacy"
       data-dependent-fields-values='["private", "protected"]'>
    <%= f.label :visibility_strategy, class: 'form-label' %>
    <%= f.select :visibility_strategy,
                 options_for_select(
                   BetterTogether::NavigationItem::VISIBILITY_STRATEGIES.map { |s| 
                     [t("navigation_items.visibility_strategies.#{s}"), s] 
                   },
                   f.object.visibility_strategy
                 ),
                 {},
                 class: 'form-select',
                 data: {
                   dependent_fields_trigger_param: 'visibility_strategy',
                   action: 'change->dependent-fields#toggle'
                 } %>
    <div class="form-text">
      <%= t('.visibility_strategy_hint') %>
    </div>
  </div>

  <!-- Permission Identifier - Only shown when visibility_strategy == 'permission' -->
  <div class="mb-3"
       data-dependent-fields-target="field"
       data-dependent-fields-dependency="visibility_strategy"
       data-dependent-fields-values='["permission"]'>
    <%= f.label :permission_identifier, class: 'form-label' %>
    <%= f.select :permission_identifier,
                 options_for_select(
                   available_permission_identifiers.map { |p| 
                     [t("permissions.#{p}", default: p.humanize), p] 
                   },
                   f.object.permission_identifier
                 ),
                 { include_blank: t('.select_permission') },
                 class: 'form-select' %>
    <div class="form-text">
      <%= t('.permission_identifier_hint') %>
    </div>
  </div>

  <!-- Rest of form fields -->
  
<% end %>
```

Helper method for available permissions:

```ruby
# app/helpers/better_together/navigation_items_helper.rb
def available_permission_identifiers
  # Return commonly used permissions for navigation items
  [
    'manage_platform',
    'view_metrics_dashboard',
    'create_metrics_reports',
    'download_metrics_reports',
    'manage_communities',
    'moderate_content'
  ]
end
```

### 8. I18n Translations

```yaml
# config/locales/en.yml
en:
  better_together:
    navigation_items:
      form:
        privacy_hint: "Controls who can see this navigation item"
        visibility_strategy_hint: "How to determine if a user can see this item"
        permission_identifier_hint: "Users must have this permission to see this item"
        select_permission: "-- Select a permission --"
      visibility_strategies:
        authenticated: "Any authenticated user"
        permission: "Users with specific permission"
  privacy:
    public: "Public"
    private: "Private"
    protected: "Protected"
  permissions:
    manage_platform: "Manage Platform"
    view_metrics_dashboard: "View Analytics Dashboard"
    create_metrics_reports: "Create Analytics Reports"
    download_metrics_reports: "Download Analytics Reports"
```

### 9. Performance Considerations

1. **Database Queries**: Use `.includes(:children)` to avoid N+1 queries
2. **Caching**: Cache filtered navigation per user role + locale combination
3. **Permission Checks**: Leverage existing `Member#permitted_to?` 12-hour cache

### 10. Security Considerations

1. **Fail Closed**: Unknown strategies or errors return `false` (not visible)
2. **Defense in Depth**: Navigation filtering is UX, not security - controllers still enforce authorization
3. **Privacy First**: Public items visible to all, non-public items require authentication

## Future Enhancements (Post-MVP)

1. **Policy-Based Strategy**: Add support for Pundit policy checks when needed
2. **Role-Based Strategy**: Direct role membership check (`visibility_strategy: 'role'`)
3. **Multiple Permissions**: Support OR logic with `permission_identifiers` array
4. **Time-Based Visibility**: Show/hide nav items based on time windows
5. **Custom Visibility Callbacks**: Register lambda-based visibility rules
6. **Admin UI**: Drag-and-drop permission configuration in dashboard

## Testing Strategy

### Unit Tests
- NavigationItem#visible_to? with privacy levels
- NavigationItem#visible_to? with both visibility strategies
- Permission checking with different user types
- Privacy concern integration
- Validation: permission_identifier cannot be set when privacy is public
- Edge cases (nil user, missing platform, blank permission_identifier)

### Integration Tests
- Navigation rendering with filtered items
- Dropdown items with mixed visibility
- Caching behavior across requests
- Backward compatibility with existing nav items (default privacy='public')

### System Tests (Form UI)
- Privacy field shows/hides visibility_strategy field using dependent-fields
- Visibility_strategy field shows/hides permission_identifier field
- Form validation prevents invalid combinations
- Stimulus controller correctly toggles dependent fields

### Feature Tests
- Platform manager sees all nav items
- Analytics viewer sees Analytics but not other management items
- Regular user sees only public items
- Authenticated user sees public + authenticated items
- Navigation updates when user gains/loses permissions

## Migration Path

1. **Deploy migration** - Adds columns with defaults (`privacy: 'private'`, `visibility_strategy: 'authenticated'`)
2. **Run rake task automatically** - Migration invokes rake task to set existing visible nav items to `privacy: 'public'`
3. **Existing nav items** - Visible items become public, maintaining current behavior
4. **Page-linked nav items** - Items linked to published pages also become public
5. **Update builders** - Set appropriate privacy and visibility strategies for new seeds
6. **Monitor & validate** - Ensure no navigation breakage in production

**Rake Task Details:**
- Task: `rake better_together:navigation_items:set_public_privacy`
- Logic: Sets `privacy='public'` for nav items where `visible=true` OR linked to published pages
- Can be run manually if needed: `bin/dc-run rake better_together:navigation_items:set_public_privacy`
- Safe to run multiple times (idempotent)

## Open Questions

1. **Should parent dropdowns be hidden if no children are visible?** 
   - Proposal: Yes - hide parent dropdown if all children are filtered out
   
2. **How to handle nav item visibility changes in real-time?**
   - Proposal: Cache bust on role/permission changes via touch on User/Role
   
3. **Should we support OR logic for multiple permissions in future?**
   - Proposal: Post-MVP - add `permission_identifiers` (plural array) for OR logic

## Success Criteria

- [ ] Analytics nav item only visible to users with `view_metrics_dashboard` or `manage_platform` permissions
- [ ] Platform management nav items properly filtered by permission
- [ ] No N+1 queries when rendering navigation
- [ ] Cached navigation per user role combination
- [ ] All tests passing
- [ ] Backward compatible with existing navigation items
- [ ] Documentation complete with usage examples
