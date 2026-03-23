# Membership Management Implementation Plan

## Overview
Add full CRUD operations for both PersonPlatformMemberships and PersonCommunityMemberships, enabling comprehensive membership management with editing capabilities.

## User Stories

### Platform Organizers
- **As a platform organizer**, I want to view all platform memberships so that I can see who has access to the platform
- **As a platform organizer**, I want to edit platform membership roles so that I can adjust user permissions
- **As a platform organizer**, I want to view individual membership details so that I can see membership history and role assignments
- **As a platform organizer**, I want to create new platform memberships so that I can invite users with specific roles
- **As a platform organizer**, I want to remove platform memberships so that I can revoke platform access

### Community Organizers  
- **As a community organizer**, I want to view all community memberships so that I can see community membership status
- **As a community organizer**, I want to edit community membership roles so that I can adjust member permissions
- **As a community organizer**, I want to view individual membership details so that I can track member engagement
- **As a community organizer**, I want to create new community memberships so that I can add members with appropriate roles
- **As a community organizer**, I want to remove community memberships so that I can manage community membership

### End Users
- **As an end user**, I want to see my platform membership details so that I understand my platform privileges
- **As an end user**, I want to see my community membership details so that I understand my community role

## Technical Requirements

### Routes to Add

#### Platform Memberships (Nested under Platforms)
```ruby
resources :platforms, only: %i[index show edit update] do
  resources :person_platform_memberships # Add full CRUD support
end
```

#### Community Memberships (Nested under Communities)  
```ruby
resources :communities do
  resources :person_community_memberships # Add full CRUD support
end
```

### Controller Actions to Implement

#### PersonPlatformMembershipsController
- `index` - List all platform memberships for the platform
- `show` - Display individual membership details  
- `new` - Form for creating new membership
- `edit` - Form for editing existing membership
- `update` - Handle membership updates
- **Existing**: `create`, `destroy`

#### PersonCommunityMembershipsController  
- `index` - List all community memberships for the community
- `show` - Display individual membership details
- `new` - Form for creating new membership  
- `edit` - Form for editing existing membership
- `update` - Handle membership updates
- **Existing**: `create`, `destroy`

### Form Fixes Required

#### Platform Membership Form
```erb
<!-- Current problematic form -->
<%= form_with(model: person_platform_membership) do |form| %>

<!-- Fixed nested form -->
<%= form_with(model: [@platform, person_platform_membership]) do |form| %>
```

#### Community Membership Form
```erb
<!-- Fixed nested form -->
<%= form_with(model: [@community, person_community_membership]) do |form| %>
```

### Authorization Requirements

#### Pundit Policies to Add/Update
- `PersonPlatformMembershipPolicy`
  - `index?` - Platform organizers and members can view
  - `show?` - Platform organizers and the member themselves
  - `new?` - Platform organizers only  
  - `edit?` - Platform organizers only
  - `update?` - Platform organizers only
  
- `PersonCommunityMembershipPolicy`
  - `index?` - Community organizers and members can view
  - `show?` - Community organizers and the member themselves
  - `new?` - Community organizers only
  - `edit?` - Community organizers only  
  - `update?` - Community organizers only

### Database Considerations

#### No schema changes needed
- Existing tables support all required fields
- `role_id` foreign key enables role editing
- Standard Better Together fields (created_at, updated_at, etc.) available

### User Interface Updates

#### Navigation Additions
- Add "Manage Members" link to platform show page
- Add "Manage Members" link to community show page
- Add breadcrumb navigation for membership pages

#### Platform Show Page Updates
- Keep existing inline membership creation form
- Add "View All Members" link to redirect to membership index
- Add "Edit" links on member list items

#### Community Show Page Updates  
- Keep existing inline membership creation form
- Add "View All Members" link to redirect to membership index
- Add "Edit" links on member list items

## Implementation Phases

### Phase 1: Platform Membership CRUD
1. Add missing routes for platform memberships
2. Implement missing controller actions (index, show, new, edit, update)
3. Fix form to work with nested routes
4. Update authorization policies  
5. Add navigation and UI updates
6. Write comprehensive test coverage

### Phase 2: Community Membership CRUD
1. Add missing routes for community memberships  
2. Implement missing controller actions (index, show, new, edit, update)
3. Create forms for community memberships
4. Update authorization policies
5. Add navigation and UI updates
6. Write comprehensive test coverage

### Phase 3: Enhanced Features
1. Bulk membership operations
2. Membership history tracking
3. Role change notifications
4. Enhanced permission management

## Test Coverage Requirements

### Controller Tests (Request Specs)
```ruby
# PersonPlatformMembershipsController
describe "GET /platforms/:platform_id/person_platform_memberships" do
  # Test index action authorization and functionality
end

describe "GET /platforms/:platform_id/person_platform_memberships/:id" do  
  # Test show action authorization and functionality
end

describe "GET /platforms/:platform_id/person_platform_memberships/new" do
  # Test new action authorization and form rendering
end

describe "GET /platforms/:platform_id/person_platform_memberships/:id/edit" do
  # Test edit action authorization and form rendering  
end

describe "PATCH /platforms/:platform_id/person_platform_memberships/:id" do
  # Test update action with valid/invalid parameters
end
```

### Feature Tests (Capybara)
```ruby
# Platform organizer membership management workflow
scenario "platform organizer manages membership roles" do
  # Test complete CRUD workflow from platform organizer perspective
end

# Community organizer membership management workflow  
scenario "community organizer manages membership roles" do
  # Test complete CRUD workflow from community organizer perspective  
end

# End user viewing their membership details
scenario "user views their membership details" do
  # Test user can see their own membership information
end
```

### Policy Tests
```ruby
# PersonPlatformMembershipPolicy tests
describe PersonPlatformMembershipPolicy do
  # Test all policy methods with different user roles and contexts
end

# PersonCommunityMembershipPolicy tests  
describe PersonCommunityMembershipPolicy do
  # Test all policy methods with different user roles and contexts
end
```

### Model Tests
```ruby
# Additional model tests if new methods are added
describe PersonPlatformMembership do
  # Test any new instance methods, validations, or scopes
end

describe PersonCommunityMembership do  
  # Test any new instance methods, validations, or scopes
end
```

## Acceptance Criteria

### Platform Membership Management
- [ ] Platform organizers can view a paginated list of all platform memberships
- [ ] Platform organizers can view detailed information about individual memberships
- [ ] Platform organizers can edit membership roles through a form interface
- [ ] Platform organizers can create new memberships with role selection
- [ ] Platform organizers can delete memberships with confirmation
- [ ] End users can view their own platform membership details
- [ ] All actions are properly authorized based on user roles
- [ ] Forms provide clear validation feedback
- [ ] Navigation is intuitive and includes breadcrumbs

### Community Membership Management  
- [ ] Community organizers can view a paginated list of all community memberships
- [ ] Community organizers can view detailed information about individual memberships
- [ ] Community organizers can edit membership roles through a form interface
- [ ] Community organizers can create new memberships with role selection
- [ ] Community organizers can delete memberships with confirmation
- [ ] End users can view their own community membership details
- [ ] All actions are properly authorized based on user roles
- [ ] Forms provide clear validation feedback
- [ ] Navigation is intuitive and includes breadcrumbs

### Technical Acceptance Criteria
- [ ] All routes follow RESTful conventions and nested resource patterns
- [ ] Forms use proper Rails form helpers with nested model binding
- [ ] Authorization policies prevent unauthorized access
- [ ] Comprehensive test coverage (>95% for new code)
- [ ] No security vulnerabilities introduced (Brakeman clean)
- [ ] No accessibility regressions (WCAG AA compliance maintained)
- [ ] I18n support for all new user-facing strings
- [ ] Responsive design works on mobile and desktop
- [ ] Turbo/Stimulus integration for dynamic interactions

## Security Considerations

### Authorization Enforcement
- All membership CRUD operations must be authorized through Pundit policies
- Users can only view/edit memberships for platforms/communities they organize
- Users can view their own membership details but cannot edit them directly
- Platform organizers cannot edit their own platform organizer membership

### Input Validation
- Role selection must be validated against available roles for the platform/community
- Member selection must validate user is not already a member (for creation)
- Nested resource validation ensures membership belongs to specified platform/community

### Audit Trail
- Membership changes should be logged for security and compliance
- Consider adding created_by/updated_by fields to track who made changes
- Role changes should trigger notifications to affected users

## Future Enhancements

### Notification Integration
- Notify users when their role is changed
- Send welcome emails for new memberships
- Alert when memberships are removed

### Advanced Permission Management
- Custom role creation and management
- Permission inheritance between platform and community roles  
- Time-limited memberships with automatic expiration

### Reporting and Analytics
- Membership growth tracking
- Role distribution analytics
- Member engagement metrics

## Dependencies

### Required Gems
- No new gem dependencies required
- Existing Pundit, Devise, and Better Together infrastructure sufficient

### Database Migrations
- No new migrations required
- Existing membership tables have all required fields

### External Services
- None required for basic implementation
- Future notification features may require email service integration

This implementation plan provides a comprehensive foundation for adding full membership management capabilities while maintaining security, accessibility, and architectural consistency with the Better Together framework.