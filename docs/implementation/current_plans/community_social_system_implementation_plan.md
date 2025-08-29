# Community & Social System Implementation Plan

## Overview

This document outlines the implementation plan for the essential missing features identified in the Community & Social System documentation. The plan prioritizes user safety, administrative tools, and core social functionality needed for a functional community platform.

## Implementation Priority Matrix

### Phase 1: Critical User Safety & Platform Organizer Tools (Weeks 1-3)
**Priority: CRITICAL** - Required for platform safety and basic moderation

1. **Report Review System** - Platform organizer interface for content moderation
2. **Block Management Interface** - User interface for safety controls
3. **Basic Moderation Tools** - Content removal and user management

### Phase 2: Core Social Features (Weeks 4-6)
**Priority: HIGH** - Required for basic community functionality

4. **Community Membership UI** - Join/leave community workflows
5. **Privacy Settings UI** - User privacy control interface

### Phase 3: Enhanced Features (Weeks 7-8)
**Priority: MEDIUM** - Quality of life improvements

6. **Advanced Moderation Tools** - Bulk actions and enhanced workflows
7. **Enhanced Privacy Controls** - Granular privacy management

## Detailed Implementation Plans

---

## 1. Report Review System (Week 1)

### Overview
Create platform organizer interface for reviewing and managing user reports about content and users.

### Models Required
```ruby
# Enhance existing Report model
class Report < ApplicationRecord
  # Add status tracking
  enum status: { pending: "pending", under_review: "under_review", resolved: "resolved", dismissed: "dismissed" }
  
  # Add reviewer tracking
  belongs_to :reviewer, class_name: 'Person', optional: true
  
  # Add resolution tracking
  validates :resolution_notes, presence: true, if: :resolved_or_dismissed?
  
  scope :pending_review, -> { where(status: :pending) }
  scope :needs_attention, -> { where(status: [:pending, :under_review]) }
end
```

### Controllers Required
```ruby
# New: BetterTogether::ReportsController (enhanced for platform organizers)
class BetterTogether::ReportsController < ApplicationController
  def index    # List all reports with filtering
  def show     # View report details and context
  def update   # Update report status and resolution
  def resolve  # Mark report as resolved with notes
  def dismiss  # Dismiss report with reason
end
```

### Views Required
- `better_together/reports/index.html.erb` - Report dashboard with filters
- `better_together/reports/show.html.erb` - Individual report review interface
- `better_together/reports/_report_card.html.erb` - Report summary component
- `better_together/reports/_resolution_form.html.erb` - Resolution action form

### Database Migration
```ruby
class EnhanceReportsForAdminReview < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_reports, :status, :string, default: "pending"
    add_reference :better_together_reports, :reviewer, type: :uuid, foreign_key: { to_table: :better_together_people }
    add_column :better_together_reports, :resolution_notes, :text
    add_column :better_together_reports, :resolved_at, :datetime
    
    add_index :better_together_reports, :status
    add_index :better_together_reports, :created_at
  end
end
```

### Key Features
- Filter reports by status, type, date range
- View reported content in context
- Take actions: resolve, dismiss, escalate
- Track resolution history and reviewer notes
- Email notifications to reporters on resolution

### Testing Requirements
- Policy tests for host community role-based access control
- Controller tests for CRUD operations
- Integration tests for report workflow
- Feature tests for platform organizer interface

---

## 2. Block Management Interface (Week 1)

### Overview
Create user-facing interface for managing blocked users, viewing block history, and unblocking users.

### Controllers Required
```ruby
# Enhance existing PersonBlocksController
class PersonBlocksController < ApplicationController
  def index    # List user's blocked people with search
  def show     # Block details and history
  def create   # Block a user (existing)
  def destroy  # Unblock a user (existing)
  def new      # Form to block a user by username/email
end
```

### Views Required
- `person_blocks/index.html.erb` - Blocked users dashboard
- `person_blocks/new.html.erb` - Block user form
- `person_blocks/_blocked_person.html.erb` - Blocked person card
- `person_blocks/_block_form.html.erb` - Quick block form component

### JavaScript Controllers
```javascript
// app/javascript/controllers/person_block_controller.js
// Handle block/unblock actions with confirmation
// Search and filter blocked users
// Quick block form submissions
```

### Key Features
- Search blocked users by name
- Quick unblock actions with confirmation
- Block user by username or email
- View block creation date and context
- Bulk unblock actions (future enhancement)

### UI/UX Considerations
- Clear confirmation dialogs for unblock actions
- Search and filter capabilities
- Responsive design for mobile devices
- Accessibility compliance (WCAG AA)

---

## 3. Basic Moderation Tools (Week 2)

### Overview
Create platform organizer tools for content removal, user suspension, and basic moderation actions.

### Models Required
```ruby
# New: PersonSuspension model
class PersonSuspension < ApplicationRecord
  belongs_to :person
  belongs_to :suspended_by, class_name: 'Person'
  
  validates :reason, presence: true
  validates :expires_at, presence: true
  
  scope :active, -> { where('expires_at > ?', Time.current) }
end

# New: ContentRemoval model  
class ContentRemoval < ApplicationRecord
  belongs_to :removed_content, polymorphic: true
  belongs_to :removed_by, class_name: 'Person'
  
  validates :reason, presence: true
  
  # Store original content for audit
  store_attributes :original_data do
    content_snapshot Text
  end
end
```

### Controllers Required
```ruby
# New: BetterTogether::ModerationController
class BetterTogether::ModerationController < ApplicationController
  def suspend_user     # Temporarily suspend user account
  def unsuspend_user   # Remove user suspension
  def remove_content   # Remove inappropriate content
  def restore_content  # Restore removed content
end
```

### Key Features
- Temporary user suspension with expiration
- Content removal with audit trail
- Bulk moderation actions
- Moderation log and history tracking
- Integration with report resolution workflow

### Database Migrations
```ruby
class CreatePersonSuspensions < ActiveRecord::Migration[7.1]
  def change
    create_table :better_together_person_suspensions, id: :uuid do |t|
      t.references :person, null: false, type: :uuid
      t.references :suspended_by, null: false, type: :uuid
      t.text :reason, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
  end
end

class CreateContentRemovals < ActiveRecord::Migration[7.1]
  def change
    create_table :better_together_content_removals, id: :uuid do |t|
      t.references :removed_content, polymorphic: true, null: false, type: :uuid
      t.references :removed_by, null: false, type: :uuid
      t.text :reason, null: false
      t.jsonb :original_data, default: {}
      t.timestamps
    end
  end
end
```

---

## 4. Community Membership UI (Week 3)

### Overview
Create user interface for joining communities, leaving communities, and managing membership status.

### Controllers Required
```ruby
# Enhance PersonCommunityMembershipsController
class PersonCommunityMembershipsController < ApplicationController
  def create   # Join community (existing, enhanced)
  def destroy  # Leave community (existing, enhanced)
  def pending  # View pending membership requests
  def approve  # Approve membership requests (community managers)
  def deny     # Deny membership requests (community managers)
end
```

### Models Required
```ruby
# Enhance PersonCommunityMembership
class PersonCommunityMembership < ApplicationRecord
  # Add membership status tracking
  enum status: { active: "active", pending: "pending", suspended: "suspended", banned: "banned" }
  
  # Add request tracking
  belongs_to :approved_by, class_name: 'Person', optional: true
  
  validates :request_message, length: { maximum: 500 }
  
  scope :pending_approval, -> { where(status: :pending) }
end
```

### Views Required
- `communities/_join_leave_buttons.html.erb` - Join/leave community controls
- `communities/_membership_status.html.erb` - Current membership status indicator
- `person_community_memberships/pending.html.erb` - Pending requests dashboard
- `person_community_memberships/_membership_request.html.erb` - Request card component

### Key Features
- One-click join for public communities
- Request-based joining for private communities
- Community manager approval workflow
- Membership status indicators
- Leave community confirmation flow

### Database Migration
```ruby
class EnhanceMembershipWorkflow < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_person_community_memberships, :status, :string, default: "active"
    add_column :better_together_person_community_memberships, :request_message, :text
    add_reference :better_together_person_community_memberships, :approved_by, type: :uuid
    add_column :better_together_person_community_memberships, :approved_at, :datetime
    
    add_index :better_together_person_community_memberships, :status
  end
end
```

---

## 5. Privacy Settings UI (Week 4)

### Overview
Create comprehensive interface for users to configure privacy settings across their profile, content, and interactions.

### Controllers Required
```ruby
# New: BetterTogether::Privacy::SettingsController
class BetterTogether::Privacy::SettingsController < ApplicationController
  def show     # Display current privacy settings
  def update   # Update privacy preferences
  def reset    # Reset to default privacy settings
end
```

### Models Required
```ruby
# Enhance Person model with privacy preferences
class Person < ApplicationRecord
  # Add privacy preferences store
  store_attributes :privacy_preferences do
    profile_visibility String, default: 'public'
    contact_visibility String, default: 'private'
    activity_visibility String, default: 'private'
    search_visibility Boolean, default: true
  end
  
  # Privacy validation
  validates :profile_visibility, inclusion: { in: %w[public private members_only] }
  validates :contact_visibility, inclusion: { in: %w[public private members_only] }
  validates :activity_visibility, inclusion: { in: %w[public private members_only] }
end
```

### Views Required
- `privacy/settings/show.html.erb` - Privacy settings dashboard
- `privacy/settings/_profile_privacy.html.erb` - Profile privacy section
- `privacy/settings/_contact_privacy.html.erb` - Contact information privacy
- `privacy/settings/_activity_privacy.html.erb` - Activity and interaction privacy

### JavaScript Controllers
```javascript
// app/javascript/controllers/privacy_settings_controller.js
// Handle privacy setting toggles
// Preview privacy changes
// Bulk privacy updates
```

### Key Features
- Granular privacy controls for different content types
- Privacy preview showing how profile appears to others
- Bulk privacy updates for existing content
- Export privacy settings and data
- Privacy education and recommendations

### Database Migration
```ruby
class AddPrivacyPreferences < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_people, :privacy_preferences, :jsonb, default: {}
    add_index :better_together_people, :privacy_preferences, using: :gin
  end
end
```

---

## Implementation Timeline

### Week 1: Platform Organizer Safety Tools
**Days 1-3: Report Review System**
- [ ] Create enhanced Report model with status tracking
- [ ] Build BetterTogether::ReportsController with full CRUD and organizer dashboard
- [ ] Create platform organizer report dashboard and detail views
- [ ] Add report resolution workflow with severity-based decision autonomy
- [ ] Write comprehensive tests

**Days 4-7: Block Management Interface**
- [ ] Enhance PersonBlocksController with search and filtering
- [ ] Create user-facing block management dashboard
- [ ] Add block user by username/email functionality
- [ ] Implement JavaScript for interactive blocking
- [ ] Add accessibility features and mobile responsiveness

### Week 2: Moderation Tools
**Days 1-4: Content Removal System**
- [ ] Create ContentRemoval model and migration
- [ ] Build content removal controllers and policies
- [ ] Add content removal audit trail
- [ ] Create platform organizer interface for content management
- [ ] Integrate with report resolution workflow

**Days 5-7: User Suspension System**
- [ ] Create PersonSuspension model and migration
- [ ] Build user suspension controllers and policies  
- [ ] Add suspension management interface
- [ ] Create suspension notification system
- [ ] Add bulk moderation capabilities

### Week 3: Community Membership
**Days 1-4: Join/Leave Workflow**
- [ ] Enhance PersonCommunityMembership with status tracking
- [ ] Build community joining interface
- [ ] Add membership request workflow for private communities
- [ ] Create community organizer approval interface
- [ ] Add membership status indicators

**Days 5-7: Membership Management**
- [ ] Build membership dashboard for users
- [ ] Add community member directory
- [ ] Create role change interface for community organizers
- [ ] Add membership analytics and reporting
- [ ] Write integration tests for complete workflow

### Week 4: Privacy Controls
**Days 1-4: Privacy Settings Interface**
- [ ] Add privacy preferences to Person model
- [ ] Create BetterTogether::Privacy::SettingsController
- [ ] Build privacy settings dashboard
- [ ] Add granular privacy controls for content types
- [ ] Create privacy preview functionality

**Days 5-7: Privacy Integration**
- [ ] Update existing views to respect privacy settings
- [ ] Add privacy-aware query scopes
- [ ] Create privacy education content
- [ ] Add data export functionality
- [ ] Comprehensive privacy testing

## Testing Strategy

### Unit Tests
- Model validations and business logic
- Policy authorization rules
- Service object functionality
- Background job processing

### Integration Tests  
- Controller actions and workflows
- Cross-model relationships
- Policy integration with controllers
- Email notifications and background jobs

### Feature Tests
- Complete user workflows (join community, block user, etc.)
- Platform organizer moderation workflows
- Privacy setting changes and effects
- Responsive design and accessibility

### Performance Tests
- Database query optimization
- Page load times for dashboards
- Bulk operation performance
- Cache effectiveness

## Security Considerations

### Authorization
- Host community role-based access to moderation tools
- User ownership verification for personal settings
- Community organizer permissions for membership approval
- Audit trails for all moderation actions
- Context-sensitive permissions based on decision autonomy granted

### Data Protection
- Secure handling of reported content
- Privacy setting enforcement across all views
- Safe deletion of user data
- Audit logging for sensitive operations

### Input Validation
- Sanitization of user-generated content
- Prevention of mass assignment vulnerabilities
- Rate limiting for report submissions
- CSRF protection for all forms

## Performance Optimization

### Database Optimization
- Proper indexing for frequently queried fields
- Query optimization for membership lookups
- Caching for privacy setting checks
- Background processing for heavy operations

### Frontend Optimization
- JavaScript lazy loading for dashboards
- Image optimization for user interfaces
- Progressive enhancement for accessibility
- Mobile-first responsive design

## Success Metrics

### User Safety
- Reduction in reported content volume
- Faster report resolution times
- Increased user satisfaction with safety tools
- Reduced repeat offenses

### Community Engagement
- Increased community join rates
- Higher member retention
- More active community participation
- Improved privacy satisfaction scores

### Platform Organizer Efficiency
- Reduced moderation workload through better tools
- Faster decision-making on reports with appropriate autonomy levels
- Better tracking of moderation actions with collaborative oversight
- Improved platform organizer user experience

---

This implementation plan provides a structured approach to building the essential missing features for the Community & Social System, prioritizing user safety and administrative tools while ensuring a comprehensive and secure social platform experience.
