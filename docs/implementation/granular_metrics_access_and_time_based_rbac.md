# Granular Metrics Access + Time-Based RBAC Implementation Plan

**Date:** December 19, 2025  
**Status:** Planning  
**Priority:** High  
**Estimated Effort:** 120-160 hours

## Executive Summary

This implementation plan addresses the need for granular access control to metrics and reporting systems without requiring full platform management permissions, while simultaneously enhancing the RBAC system with time-based role assignments, approval workflows, and an extensible section access control UI. The plan also includes critical security fixes identified in the RBAC assessment and integration of PaperTrail audit logging with GDPR-compliant retention.

## Business Requirements

### Primary Goals

1. **Granular Metrics Access**: Enable delegation of analytics responsibilities to users without granting full platform management privileges
2. **Time-Based Role Assignments**: Support temporary role grants with optional expiration and renewal workflows
3. **Extensible Section Access UI**: Provide intuitive interface for managing access to platform sections (starting with metrics)
4. **Audit Trail**: Track all RBAC changes for security and compliance
5. **Security Hardening**: Fix critical authorization gaps in platform management

### User Stories

**Analytics Delegation:**
- As a Platform Manager, I want to grant read-only analytics access to a Data Analyst without giving them platform management permissions
- As a Content Editor, I want to view page view metrics for my content without accessing other platform settings
- As a Marketing Coordinator, I want to generate and download reports on engagement metrics

**Time-Based Access:**
- As a Community Coordinator, I want to grant temporary moderator access for 7 days while the regular moderator is on vacation
- As a Platform Manager, I want contractor access to automatically expire after 30 days
- As a User, I want to receive a notification 7 days before my role expires so I can request renewal

**Section Access Management:**
- As a Platform Manager, I want to see who has access to view and edit specific platform sections
- As a Platform Manager, I want to easily grant time-limited access to sections like metrics or user management
- As a Platform Manager, I want to review and approve role renewal requests

## Technical Architecture

### New Models

#### 1. SectionAccess Model
```ruby
# app/models/better_together/section_access.rb
class BetterTogether::SectionAccess < ApplicationRecord
  belongs_to :person, class_name: 'BetterTogether::Person'
  belongs_to :granted_by, class_name: 'BetterTogether::Person'
  
  enum access_level: {
    viewer: 'viewer',
    editor: 'editor', 
    manager: 'manager'
  }
  
  validates :section_identifier, presence: true
  validates :access_level, presence: true
  validate :valid_until_after_valid_from
  
  scope :active, -> {
    where('valid_from IS NULL OR valid_from <= ?', Time.current)
      .where('valid_until IS NULL OR valid_until > ?', Time.current)
  }
  
  scope :for_section, ->(identifier) { where(section_identifier: identifier) }
end
```

**Schema:**
- `section_identifier` (string, indexed) - e.g., 'metrics', 'platform_settings', 'user_management'
- `person_id` (uuid, FK)
- `access_level` (string enum: viewer/editor/manager)
- `granted_by_id` (uuid, FK to people)
- `granted_at` (datetime)
- `valid_from` (datetime, nullable)
- `valid_until` (datetime, nullable)
- `notes` (text)
- Unique index on `(section_identifier, person_id, access_level)` where not expired

#### 2. RoleRequest Model
```ruby
# app/models/better_together/role_request.rb
class BetterTogether::RoleRequest < ApplicationRecord
  belongs_to :requester, class_name: 'BetterTogether::Person'
  belongs_to :role, class_name: 'BetterTogether::Role'
  belongs_to :joinable, polymorphic: true
  belongs_to :reviewer, class_name: 'BetterTogether::Person', optional: true
  
  enum status: {
    pending: 'pending',
    approved: 'approved',
    denied: 'denied'
  }
  
  validates :reason, presence: true
  validates :status, presence: true
end
```

**Schema:**
- `requester_id` (uuid, FK to people)
- `role_id` (uuid, FK to roles)
- `joinable_id` (uuid)
- `joinable_type` (string)
- `status` (string: pending/approved/denied)
- `reason` (text, required)
- `reviewer_id` (uuid, FK to people, nullable)
- `review_notes` (text, nullable)
- `reviewed_at` (datetime, nullable)
- `valid_from` (datetime, nullable)
- `valid_until` (datetime, nullable)
- Unique index on `(requester_id, role_id, joinable_id, joinable_type)` where status='pending'

#### 3. RoleRenewalRequest Model
```ruby
# app/models/better_together/role_renewal_request.rb
class BetterTogether::RoleRenewalRequest < ApplicationRecord
  belongs_to :membership, polymorphic: true
  belongs_to :requester, class_name: 'BetterTogether::Person'
  belongs_to :reviewer, class_name: 'BetterTogether::Person', optional: true
  
  enum status: {
    pending: 'pending',
    approved: 'approved',
    denied: 'denied'
  }
end
```

**Schema:**
- `membership_id` (uuid)
- `membership_type` (string: PersonPlatformMembership/PersonCommunityMembership)
- `requester_id` (uuid, FK to people)
- `status` (string: pending/approved/denied)
- `reviewer_id` (uuid, FK to people, nullable)
- `review_notes` (text, nullable)
- `reviewed_at` (datetime, nullable)
- `extension_period` (interval, e.g., '30 days')
- Unique index on `(membership_id, membership_type)` where status='pending'

### Model Enhancements

#### Membership Concern Updates
```ruby
# app/models/concerns/better_together/membership.rb
module BetterTogether::Membership
  extend ActiveSupport::Concern
  
  included do
    # New fields: valid_from, valid_until, auto_renew, renewal_requires_approval
    
    validates :valid_until, comparison: { greater_than: :valid_from },
              if: -> { valid_from.present? && valid_until.present? }
    
    scope :active, -> {
      where('valid_from IS NULL OR valid_from <= ?', Time.current)
        .where('valid_until IS NULL OR valid_until > ?', Time.current)
    }
    
    scope :expired, -> {
      where('valid_until IS NOT NULL AND valid_until <= ?', Time.current)
    }
    
    scope :pending, -> {
      where('valid_from IS NOT NULL AND valid_from > ?', Time.current)
    }
    
    scope :renewable, -> {
      expired.where(auto_renew: true)
    }
    
    after_save :invalidate_member_permission_cache
    
    def active?
      (valid_from.nil? || valid_from <= Time.current) &&
      (valid_until.nil? || valid_until > Time.current)
    end
    
    def expired?
      valid_until.present? && valid_until <= Time.current
    end
    
    def renewable?
      expired? && auto_renew?
    end
    
    private
    
    def invalidate_member_permission_cache
      member.touch # Bumps cache_key_with_version
    end
  end
end
```

#### Member Concern Updates
```ruby
# app/models/concerns/better_together/member.rb
module BetterTogether::Member
  # Update permission checking to filter active memberships only
  def record_permission_granted?(resource_permission, record)
    membership_class = membership_class_for(record)
    return false unless membership_class

    # CHANGED: Filter to active memberships only
    memberships = membership_class.active.where(
      member: self,
      joinable_id: record.id
    ).includes(:role)

    memberships.any? do |membership|
      membership.role.role_resource_permissions.exists?(
        resource_permission_id: resource_permission.id
      )
    end
  end
  
  # Reduce cache TTL from 12 hours to 5 minutes
  def permitted_to?(permission_identifier, record = nil)
    Rails.cache.fetch(cache_key_for(:permitted_to, permission_identifier, record), 
                      expires_in: 5.minutes) do
      # ... existing logic
    end
  end
end
```

### New Permissions

#### Granular Metrics Permissions
```ruby
# In AccessControlBuilder#build_resource_permissions
{
  identifier: 'view_metrics_dashboard',
  action: 'view',
  resource_type: 'BetterTogether::Metrics',
  position: 16
},
{
  identifier: 'generate_metrics_reports',
  action: 'create',
  resource_type: 'BetterTogether::Metrics::Report',
  position: 17
},
{
  identifier: 'download_metrics_reports',
  action: 'read',
  resource_type: 'BetterTogether::Metrics::Report',
  position: 18
}
```

### New Policies

#### Metrics Policies
```ruby
# app/policies/better_together/metrics/reports_policy.rb
class BetterTogether::Metrics::ReportsPolicy < ApplicationPolicy
  def index?
    permitted_to?('view_metrics_dashboard') || permitted_to?('manage_platform')
  end
end

# app/policies/better_together/metrics/page_view_report_policy.rb
class BetterTogether::Metrics::PageViewReportPolicy < ApplicationPolicy
  def index?
    permitted_to?('view_metrics_dashboard') || permitted_to?('manage_platform')
  end
  
  def create?
    permitted_to?('generate_metrics_reports') || permitted_to?('manage_platform')
  end
  
  def download?
    permitted_to?('download_metrics_reports') || permitted_to?('manage_platform')
  end
end

# Similar for LinkClickReportPolicy and LinkCheckerReportPolicy
```

#### Section Access Policy
```ruby
# app/policies/better_together/section_access_policy.rb
class BetterTogether::SectionAccessPolicy < ApplicationPolicy
  def index?
    permitted_to?('manage_platform')
  end
  
  def create?
    permitted_to?('manage_platform')
  end
  
  def destroy?
    permitted_to?('manage_platform')
  end
end
```

#### Host Dashboard Policy
```ruby
# app/policies/better_together/host_dashboard_policy.rb
class BetterTogether::HostDashboardPolicy < ApplicationPolicy
  def index?
    permitted_to?('manage_platform')
  end
end
```

#### Role Request Policies
```ruby
# app/policies/better_together/role_request_policy.rb
class BetterTogether::RoleRequestPolicy < ApplicationPolicy
  def create?
    user.present? && record.requester == agent
  end
  
  def approve?
    return false unless permitted_to?('manage_platform')
    
    # Platform managers can approve any role
    # Community coordinators can approve community roles for their communities
    if record.joinable_type == 'BetterTogether::Community'
      permitted_to?('manage_community_roles', record.joinable) ||
        permitted_to?('manage_platform')
    else
      permitted_to?('manage_platform')
    end
  end
  
  def deny?
    approve? # Same authorization as approve
  end
end

# app/policies/better_together/role_renewal_request_policy.rb
class BetterTogether::RoleRenewalRequestPolicy < ApplicationPolicy
  def approve?
    # Platform managers can approve any renewal
    permitted_to?('manage_platform')
  end
  
  def deny?
    approve?
  end
end
```

### Background Jobs

#### Membership Expiration Scanner
```ruby
# app/jobs/better_together/membership_expiration_scanner_job.rb
class BetterTogether::MembershipExpirationScannerJob < ApplicationJob
  queue_as :rbac
  
  def perform
    # Find memberships expiring in next 24 hours
    schedule_expiration_jobs
    
    # Send 7-day warnings
    send_expiration_warnings
  end
  
  private
  
  def schedule_expiration_jobs
    expiring_soon = (
      PersonCommunityMembership.where(valid_until: Time.current..24.hours.from_now) +
      PersonPlatformMembership.where(valid_until: Time.current..24.hours.from_now)
    )
    
    expiring_soon.each do |membership|
      MembershipExpirationJob.set(wait_until: membership.valid_until)
                            .perform_later(membership.class.name, membership.id)
    end
  end
  
  def send_expiration_warnings
    expiring_in_week = (
      PersonCommunityMembership.where(valid_until: 7.days.from_now..8.days.from_now) +
      PersonPlatformMembership.where(valid_until: 7.days.from_now..8.days.from_now)
    )
    
    expiring_in_week.each do |membership|
      MembershipExpiringNotification.with(
        membership: membership,
        days_remaining: 7
      ).deliver_later(membership.member)
    end
  end
end
```

#### Membership Expiration Handler
```ruby
# app/jobs/better_together/membership_expiration_job.rb
class BetterTogether::MembershipExpirationJob < ApplicationJob
  queue_as :rbac
  
  def perform(membership_type, membership_id)
    membership = membership_type.constantize.find_by(id: membership_id)
    return unless membership
    return unless membership.expired?
    
    if membership.auto_renew && membership.renewal_requires_approval
      # Create renewal request for platform manager approval
      create_renewal_request(membership)
    elsif membership.auto_renew && !membership.renewal_requires_approval
      # Auto-extend by 30 days
      membership.update!(valid_until: 30.days.from_now)
      notify_auto_renewal(membership)
    else
      # No auto-renewal - expire and notify
      expire_membership(membership)
    end
  end
  
  private
  
  def create_renewal_request(membership)
    request = RoleRenewalRequest.create!(
      membership: membership,
      requester: membership.member,
      status: 'pending',
      extension_period: '30 days'
    )
    
    # Notify platform managers
    notify_platform_managers_of_renewal_request(request)
  end
  
  def expire_membership(membership)
    MembershipExpiredNotification.with(membership: membership)
                                 .deliver_later(membership.member)
    membership.destroy
  end
end
```

#### PaperTrail Cleanup
```ruby
# app/jobs/better_together/versions_cleanup_job.rb
class BetterTogether::VersionsCleanupJob < ApplicationJob
  queue_as :maintenance
  
  def perform
    cutoff_date = 180.days.ago
    
    # Find versions older than 180 days
    old_versions = PaperTrail::Version.where('created_at < ?', cutoff_date)
    
    # Anonymize whodunnit for GDPR compliance
    old_versions.find_each do |version|
      if version.whodunnit.present?
        anonymized_id = "deleted_user_#{Digest::SHA256.hexdigest(version.whodunnit)[0..7]}"
        version.update_column(:whodunnit, anonymized_id)
      end
    end
    
    # Delete anonymized versions
    old_versions.delete_all
  end
end
```

### Notifications

#### New Notification Classes
1. `MembershipExpiringNotification` - 7-day warning before expiration
2. `MembershipExpiredNotification` - Sent when membership expires
3. `RoleRequestSubmittedNotification` - Sent to coordinators when user requests role
4. `RoleRequestApprovedNotification` - Sent to requester when approved
5. `RoleRequestDeniedNotification` - Sent to requester when denied
6. `RoleAssignedNotification` - Sent when role is assigned to user
7. `RoleRevokedNotification` - Sent when role is removed
8. `RoleRenewalRequestNotification` - Sent to platform managers for approval

### Controllers

#### Section Accesses Controller
```ruby
# app/controllers/better_together/section_accesses_controller.rb
class BetterTogether::SectionAccessesController < ApplicationController
  before_action :set_section_identifier
  
  def index
    authorize SectionAccess
    @section_accesses = policy_scope(SectionAccess)
                          .for_section(@section_identifier)
                          .includes(:person, :granted_by)
                          .order(granted_at: :desc)
    @new_section_access = SectionAccess.new(section_identifier: @section_identifier)
  end
  
  def create
    @section_access = SectionAccess.new(section_access_params)
    @section_access.section_identifier = @section_identifier
    @section_access.granted_by = current_person
    @section_access.granted_at = Time.current
    
    authorize @section_access
    
    if @section_access.save
      # Turbo Stream response
    else
      # Error handling
    end
  end
  
  def destroy
    @section_access = SectionAccess.find(params[:id])
    authorize @section_access
    @section_access.destroy
    # Turbo Stream response
  end
  
  private
  
  def set_section_identifier
    @section_identifier = params[:section_identifier]
  end
end
```

#### Role Requests Controller
```ruby
# app/controllers/better_together/role_requests_controller.rb
class BetterTogether::RoleRequestsController < ApplicationController
  def index
    if permitted_to?('manage_platform')
      @role_requests = RoleRequest.pending.order(created_at: :asc)
    else
      @role_requests = RoleRequest.where(requester: current_person)
    end
  end
  
  def create
    @role_request = RoleRequest.new(role_request_params)
    @role_request.requester = current_person
    @role_request.status = 'pending'
    
    authorize @role_request
    
    if @role_request.save
      notify_coordinators
      # Success response
    else
      # Error handling
    end
  end
  
  def approve
    @role_request = RoleRequest.find(params[:id])
    authorize @role_request
    
    # Create membership
    create_membership_from_request(@role_request)
    
    # Update request
    @role_request.update!(
      status: 'approved',
      reviewer: current_person,
      reviewed_at: Time.current
    )
    
    # Notify requester
  end
  
  def deny
    @role_request = RoleRequest.find(params[:id])
    authorize @role_request
    
    @role_request.update!(
      status: 'denied',
      reviewer: current_person,
      reviewed_at: Time.current,
      review_notes: params[:review_notes]
    )
    
    # Notify requester
  end
end
```

#### Role Renewal Requests Controller
```ruby
# app/controllers/better_together/role_renewal_requests_controller.rb
class BetterTogether::RoleRenewalRequestsController < ApplicationController
  def index
    authorize RoleRenewalRequest
    @renewal_requests = RoleRenewalRequest.pending.order(created_at: :asc)
  end
  
  def approve
    @renewal_request = RoleRenewalRequest.find(params[:id])
    authorize @renewal_request
    
    # Extend membership
    extend_membership(@renewal_request)
    
    # Update request
    @renewal_request.update!(
      status: 'approved',
      reviewer: current_person,
      reviewed_at: Time.current
    )
  end
  
  def deny
    @renewal_request = RoleRenewalRequest.find(params[:id])
    authorize @renewal_request
    
    @renewal_request.update!(
      status: 'denied',
      reviewer: current_person,
      reviewed_at: Time.current,
      review_notes: params[:review_notes]
    )
    
    # Membership will expire naturally
  end
end
```

#### Versions Controller (Audit Logs)
```ruby
# app/controllers/better_together/versions_controller.rb
class BetterTogether::VersionsController < ApplicationController
  def index
    authorize :version, :index?
    
    @versions = PaperTrail::Version
                  .where(item_type: ['BetterTogether::Role',
                                    'BetterTogether::ResourcePermission',
                                    'BetterTogether::PersonPlatformMembership',
                                    'BetterTogether::PersonCommunityMembership'])
                  .order(created_at: :desc)
                  .page(params[:page])
                  .per(50)
  end
end
```

### Views and UI Components

#### Section Access Management Interface
**Location:** `app/views/better_together/section_accesses/index.html.erb`

**Layout:**
- Two-column responsive layout
- Left column: Table of people with access (sortable, filterable)
- Right column/modal: Grant access form in Turbo Frame

**Features:**
- Person search with SlimSelect
- Access level radio buttons (viewer/editor/manager)
- Optional expiration datetime picker (Flatpickr)
- Notes textarea
- Inline edit for changing access levels
- Quick revoke button

#### Enhanced Membership Form
**Location:** `app/views/better_together/communities/show.html.erb` (modal)

**New Fields:**
- Valid From datetime picker (optional)
- Valid Until datetime picker (optional)
- Auto-renew checkbox
- Renewal requires approval checkbox (disabled if !auto_renew)
- Delegation reason textarea (shown only if current user delegating)

#### Member List Enhancements
**Features:**
- Status badges: Active, Expires in X days, Expired, Pending
- Filter controls (Turbo Frame):
  - Role dropdown filter
  - Status radio buttons (all/active/expired/pending)
  - Search input
- Role preview info icon with popover showing permissions

#### Audit Log Tab
**Location:** `app/views/better_together/roles/show.html.erb`

**New Tab:**
- Table showing PaperTrail versions
- Columns: Event, Actor, Changes (JSON diff), IP Address, Timestamp
- Pagination
- Filter by event type

#### Role Request Dashboard
**Locations:**
- Platform managers: `host/role_requests`
- Community coordinators: `communities/:id/role_requests`

**Features:**
- Table of pending requests
- Quick approve/deny buttons
- Modal for review notes
- Status indicators

### Stimulus Controllers

#### Section Access Controller
```javascript
// app/javascript/controllers/better_together/section_access_controller.js
export default class extends Controller {
  static targets = ["modal", "form", "accessTable"]
  
  openGrantModal() {
    this.modal.show()
  }
  
  closeModal() {
    this.modal.hide()
  }
  
  handleSuccess(event) {
    // Update table via Turbo Stream
    this.closeModal()
  }
  
  toggleInlineEdit(event) {
    // Enable inline editing of access level
  }
}
```

### Routing Updates

```ruby
# config/routes.rb

# Update metrics constraint
authenticated :user, ->(u) { u.permitted_to?('view_metrics_dashboard') } do
  scope path: 'host' do
    namespace :metrics do
      resources :reports, only: [:index]
      resources :page_view_reports, only: %i[index new create]
      resources :link_click_reports, only: %i[index new create]
      resources :link_checker_reports, only: %i[index new create]
    end
  end
end

# Section access routes
authenticated :user, ->(u) { u.permitted_to?('manage_platform') } do
  scope path: 'host' do
    resources :section_accesses, path: 'sections/:section_identifier/accesses',
              only: %i[index create destroy]
    
    resources :role_requests, only: %i[index create] do
      member do
        post :approve
        post :deny
      end
    end
    
    resources :role_renewal_requests, only: [:index] do
      member do
        post :approve
        post :deny
      end
    end
    
    resources :versions, only: [:index], path: 'audit_logs'
  end
end
```

### Navigation Updates

```ruby
# app/builders/better_together/navigation_builder.rb
def build_host
  # After "Resource Permissions" item, add:
  
  analytics_nav_item = host_nav_item.navigation_items.create!(
    title_en: 'Analytics',
    slug_en: 'analytics',
    position: 8,
    visible: true,
    protected: true,
    item_type: 'link',
    url: '/host/metrics/reports',
    icon_class: 'fa-chart-line',
    permission_to_view: 'view_metrics_dashboard'
  )
end
```

## Implementation Phases

### Phase 1: Critical Security Fixes (Week 1)
**Effort:** 16 hours

1. Fix `HostDashboardController` authorization gap
2. Fix `ApplicationPolicy::Scope` platform isolation
3. Replace `user.permitted_to?` with `agent.permitted_to?`
4. Add cache invalidation to membership models
5. Reduce permission cache TTL to 5 minutes

**Testing:**
- Policy specs for fixed authorization
- Request specs for unauthorized access (403 responses)
- Integration specs for cross-platform isolation

### Phase 2: PaperTrail Integration (Week 1-2)
**Effort:** 12 hours

1. Add PaperTrail gem and run installer
2. Configure `has_paper_trail` on RBAC models
3. Set up `ApplicationController` whodunnit tracking
4. Create `VersionsCleanupJob` with GDPR anonymization
5. Create `VersionsController` and audit log UI
6. Add to `sidekiq_cron.yml` (weekly execution)

**Testing:**
- Version creation specs on model changes
- Cleanup job specs with time freezing
- Anonymization verification specs
- Controller specs for audit log viewing

### Phase 3: Granular Metrics Permissions (Week 2)
**Effort:** 20 hours

1. Add three new permissions to `AccessControlBuilder`
2. Create `platform_analytics_viewer` role
3. Create all metrics policies
4. Add `authorize` calls to metrics controllers
5. Update metrics routes constraint
6. Add Analytics navigation item
7. Update existing platform roles to include new permissions

**Testing:**
- Policy specs for all metrics policies
- Request specs for metrics controllers
- Feature specs for analytics navigation visibility
- Integration specs for complete analytics workflow

### Phase 4: Time-Based Memberships (Week 3)
**Effort:** 24 hours

1. Create migration for membership time fields
2. Update `Membership` concern with scopes and validations
3. Update `Member` concern permission checking
4. Create expiration jobs (scanner + handler)
5. Add to `sidekiq_cron.yml` (daily scanner)
6. Create expiration notifications
7. Update membership forms with datetime pickers

**Testing:**
- Model specs for time-based scopes
- Validation specs for date ranges
- Job specs with time freezing
- Notification delivery specs
- Feature specs for membership forms

### Phase 5: Section Access System (Week 4)
**Effort:** 28 hours

1. Create `SectionAccess` model and migration
2. Create `SectionAccessPolicy`
3. Create `SectionAccessesController`
4. Build section access management UI
5. Create Stimulus controller
6. Add "Manage Access" buttons to sections
7. Create helper methods for access checking

**Testing:**
- Model specs for `SectionAccess`
- Policy specs for authorization
- Controller specs for CRUD operations
- Feature specs for UI interactions
- Stimulus controller specs

### Phase 6: Role Request Workflows (Week 5)
**Effort:** 32 hours

1. Create `RoleRequest` and `RoleRenewalRequest` models
2. Create policies for both models
3. Create controllers for both models
4. Build request submission UI
5. Build approval dashboard UI
6. Create all request/renewal notifications
7. Integrate with expiration jobs

**Testing:**
- Model specs for request models
- Policy specs for approval authorization
- Controller specs for request lifecycle
- Integration specs for complete workflows
- Notification delivery specs
- Feature specs for UI flows

### Phase 7: RBAC UI Enhancements (Week 6)
**Effort:** 28 hours

1. Add delegation tracking to memberships
2. Update community member forms
3. Create member filter/search interface
4. Add status badges to member cards
5. Create role preview popover
6. Build membership history timeline
7. Add audit log tabs to role pages

**Testing:**
- Feature specs for enhanced forms
- Filter/search functionality specs
- Timeline visualization specs
- Popover interaction specs

## Database Migrations

### Migration 1: Add Time Fields to Memberships
```ruby
class AddTimeFieldsToMemberships < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_person_platform_memberships, :valid_from, :datetime
    add_column :better_together_person_platform_memberships, :valid_until, :datetime
    add_column :better_together_person_platform_memberships, :auto_renew, :boolean, default: false
    add_column :better_together_person_platform_memberships, :renewal_requires_approval, :boolean, default: true
    
    add_column :better_together_person_community_memberships, :valid_from, :datetime
    add_column :better_together_person_community_memberships, :valid_until, :datetime
    add_column :better_together_person_community_memberships, :auto_renew, :boolean, default: false
    add_column :better_together_person_community_memberships, :renewal_requires_approval, :boolean, default: true
    
    add_index :better_together_person_platform_memberships, :valid_until
    add_index :better_together_person_community_memberships, :valid_until
  end
end
```

### Migration 2: Add Delegation Fields to Memberships
```ruby
class AddDelegationFieldsToMemberships < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_person_platform_memberships, :delegated_by_id, :uuid
    add_column :better_together_person_platform_memberships, :delegation_reason, :text
    
    add_column :better_together_person_community_memberships, :delegated_by_id, :uuid
    add_column :better_together_person_community_memberships, :delegation_reason, :text
    
    add_foreign_key :better_together_person_platform_memberships,
                    :better_together_people,
                    column: :delegated_by_id
    add_foreign_key :better_together_person_community_memberships,
                    :better_together_people,
                    column: :delegated_by_id
  end
end
```

### Migration 3: Create Section Accesses
```ruby
class CreateBetterTogetherSectionAccesses < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :section_accesses do |t|
      t.string :section_identifier, null: false
      t.bt_references :person, null: false
      t.string :access_level, null: false
      t.bt_references :granted_by, target_table: :better_together_people, null: false
      t.datetime :granted_at, null: false
      t.datetime :valid_from
      t.datetime :valid_until
      t.text :notes
      
      t.index :section_identifier
      t.index [:section_identifier, :person_id, :access_level],
              name: 'index_section_accesses_unique',
              unique: true,
              where: 'valid_until IS NULL OR valid_until > CURRENT_TIMESTAMP'
    end
  end
end
```

### Migration 4: Create Role Requests
```ruby
class CreateBetterTogetherRoleRequests < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :role_requests do |t|
      t.bt_references :requester, target_table: :better_together_people, null: false
      t.bt_references :role, null: false
      t.bt_references :joinable, polymorphic: true, null: false
      
      t.string :status, default: 'pending', null: false
      t.text :reason, null: false
      
      t.bt_references :reviewer, target_table: :better_together_people
      t.text :review_notes
      t.datetime :reviewed_at
      
      t.datetime :valid_from
      t.datetime :valid_until
      
      t.index [:requester_id, :role_id, :joinable_id, :joinable_type],
              name: 'index_role_requests_unique',
              unique: true,
              where: "status = 'pending'"
      t.index :status
    end
  end
end
```

### Migration 5: Create Role Renewal Requests
```ruby
class CreateBetterTogetherRoleRenewalRequests < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :role_renewal_requests do |t|
      t.uuid :membership_id, null: false
      t.string :membership_type, null: false
      
      t.bt_references :requester, target_table: :better_together_people, null: false
      t.string :status, default: 'pending', null: false
      
      t.bt_references :reviewer, target_table: :better_together_people
      t.text :review_notes
      t.datetime :reviewed_at
      
      t.interval :extension_period, default: '30 days'
      
      t.index [:membership_id, :membership_type],
              name: 'index_renewal_requests_unique',
              unique: true,
              where: "status = 'pending'"
      t.index :status
    end
  end
end
```

## Sidekiq Cron Configuration

```yaml
# config/sidekiq_cron.yml
membership_expiration_scanner:
  cron: "0 2 * * *"  # Daily at 2 AM UTC
  class: "BetterTogether::MembershipExpirationScannerJob"
  queue: rbac
  description: "Scans for expiring memberships and schedules expiration jobs"

versions_cleanup:
  cron: "0 3 * * 0"  # Weekly on Sunday at 3 AM UTC
  class: "BetterTogether::VersionsCleanupJob"
  queue: maintenance
  description: "Anonymizes and deletes PaperTrail versions older than 180 days for GDPR compliance"
```

## Testing Strategy

### Test Coverage Requirements
- Policy specs: 100% coverage for all authorization methods
- Model specs: 100% coverage for validations, scopes, methods
- Controller specs: Coverage for all actions and error paths
- Job specs: Coverage for all execution paths with time manipulation
- Integration specs: Complete workflows from user perspective
- Feature specs: Critical user journeys with JavaScript interactions

### Test Data Patterns
```ruby
# FactoryBot patterns for new models
FactoryBot.define do
  factory :section_access, class: 'BetterTogether::SectionAccess' do
    association :person
    association :granted_by, factory: :person
    section_identifier { 'metrics' }
    access_level { 'viewer' }
    granted_at { Time.current }
  end
  
  factory :role_request, class: 'BetterTogether::RoleRequest' do
    association :requester, factory: :person
    association :role
    association :joinable, factory: :community
    status { 'pending' }
    reason { 'I need this role to perform my duties' }
  end
end
```

## Security Considerations

### Critical Fixes
1. **Platform Isolation**: Ensure all membership queries filter by current platform
2. **Authorization Consistency**: Standardize on `agent.permitted_to?` across all policies
3. **Cache Invalidation**: Prevent stale permission checks after role changes
4. **Host Dashboard**: Add missing authorization to prevent unauthorized access

### GDPR Compliance
1. **Data Minimization**: PaperTrail tracks only necessary metadata
2. **Right to Erasure**: Anonymize `whodunnit` on user deletion
3. **Retention Limits**: Auto-delete versions older than 180 days
4. **Audit Transparency**: Users can request their audit history

### Access Control Best Practices
1. **Least Privilege**: Default to most restrictive access level
2. **Time Bounds**: Encourage setting expiration on all access grants
3. **Approval Workflows**: Require approval for auto-renewals by default
4. **Audit Trail**: All access grants logged with grantor and reason

## Performance Considerations

### Caching Strategy
- Permission cache TTL reduced to 5 minutes (was 12 hours)
- Cache invalidation on membership save triggers `member.touch`
- Section access checks cached per-request
- PaperTrail versions indexed on `item_type` and `created_at`

### Database Optimization
- Partial unique indexes on section accesses (where not expired)
- Partial unique indexes on role requests (where status='pending')
- Composite indexes on frequently queried columns
- `active` scope uses efficient date comparisons

### Background Job Optimization
- Scanner job batches operations to minimize database queries
- Individual expiration jobs can be retried independently
- Cleanup job processes versions in batches of 1000

## Deployment Checklist

### Pre-Deployment
- [ ] Run all migrations in staging environment
- [ ] Seed new permissions and roles
- [ ] Verify PaperTrail installation
- [ ] Configure Sidekiq Cron schedule
- [ ] Test email delivery for notifications
- [ ] Run full test suite

### Deployment
- [ ] Deploy code to production
- [ ] Run migrations
- [ ] Seed new data (permissions, roles, navigation)
- [ ] Verify Sidekiq Cron jobs loaded
- [ ] Monitor error logs for authorization failures
- [ ] Verify audit log creation on RBAC changes

### Post-Deployment
- [ ] Monitor permission cache performance
- [ ] Verify expiration scanner runs successfully
- [ ] Check notification delivery rates
- [ ] Review audit logs for completeness
- [ ] Gather user feedback on new UI

## Rollback Plan

### Critical Issues
If critical authorization bypass discovered:
1. Immediately revert route constraint changes
2. Disable new controllers via feature flag
3. Restore 12-hour cache TTL temporarily
4. Deploy hotfix with corrected authorization

### Data Issues
If time-based memberships cause problems:
1. Disable expiration scanner job
2. Set all `valid_until` to NULL for active memberships
3. Fix logic and re-enable

## Monitoring and Metrics

### Key Metrics to Track
- Permission check cache hit rate
- Average permission check duration
- Expiration job success rate
- Renewal request approval rate
- Section access grant frequency
- Audit log growth rate

### Alerts to Configure
- Failed expiration scanner job
- Expiration job retry exhaustion
- Unusual spike in permission denials
- PaperTrail version table size exceeding threshold
- Cache invalidation rate anomalies

## Future Enhancements (Deferred)

### Conditional Assignments (Phase 2)
- Add `conditions:jsonb` column to memberships
- Implement condition evaluation engine
- Support time-of-day, location, usage-based rules
- Build UI for setting complex conditions

### Platform Permission Granularity (Phase 2)
- Split `manage_platform` into 8+ specific permissions
- Migrate existing platform manager roles
- Update all policies to check granular permissions
- Provide migration path for custom roles

### Advanced Features (Phase 3+)
- Attribute-level permissions (can edit specific fields)
- Hierarchical permission inheritance
- Role delegation workflows
- Bulk role assignment operations
- Advanced audit log analytics
- Compliance report generation

## Stakeholder Acceptance Criteria

### End Users
- ✅ Can request roles through intuitive UI
- ✅ Receive notifications about role changes
- ✅ See when their roles will expire
- ✅ Can renew expiring roles when auto-renew enabled

### Community Organizers
- ✅ Can approve community role requests
- ✅ Can see who has access to community sections
- ✅ Can grant temporary moderator access
- ✅ Receive notifications for pending approvals

### Platform Organizers
- ✅ Can grant analytics access without full platform permissions
- ✅ Can approve any role renewal request
- ✅ Can view complete audit trail of RBAC changes
- ✅ Can manage section access for all platform areas
- ✅ See clear expiration status for all memberships

### Developers
- ✅ Security vulnerabilities fixed
- ✅ Comprehensive test coverage
- ✅ PaperTrail audit trail operational
- ✅ Performance metrics within acceptable ranges
- ✅ GDPR compliance verified

## Documentation Requirements

### User Documentation
- Guide for requesting roles
- Guide for platform managers on granting section access
- Guide for reviewing and approving role requests
- FAQ on time-based access and renewals

### Developer Documentation
- Section access system architecture
- Time-based membership implementation
- PaperTrail configuration and usage
- Notification system integration
- Testing patterns for new features

### API Documentation
- Section access endpoints
- Role request endpoints
- Audit log query endpoints

## Success Criteria

### Functional
- ✅ Platform managers can delegate analytics access without security risks
- ✅ Time-based memberships expire automatically
- ✅ Renewal workflow functions correctly
- ✅ Section access UI is intuitive and responsive
- ✅ Audit trail captures all RBAC changes

### Non-Functional
- ✅ Permission checks complete in <10ms (95th percentile)
- ✅ No unauthorized access possible
- ✅ 95%+ test coverage on new code
- ✅ Zero N+1 queries in critical paths
- ✅ GDPR compliance verified

### User Experience
- ✅ Clear status indicators for membership expiration
- ✅ Smooth Turbo-powered interactions
- ✅ Accessible to keyboard and screen reader users
- ✅ Mobile-responsive layouts
- ✅ Helpful error messages and validation feedback

## Dependencies

### Gems
- `paper_trail` - Audit logging
- `pundit` - Authorization (existing)
- `sidekiq` - Background jobs (existing)
- `sidekiq-cron` - Scheduled jobs (existing)
- `noticed` - Notifications (existing)
- `flatpickr-rails` - Datetime picker (may need to add)

### JavaScript
- Stimulus (existing)
- Turbo (existing)
- SlimSelect (existing)
- Bootstrap 5 (existing)
- Flatpickr (for datetime picking)

## Open Questions

1. **Section access integration**: Should `SectionAccess` override or supplement role-based permissions?
   - **Recommendation**: Supplement (OR logic) to allow both paths

2. **Section identifier registry**: Maintain `Section` model or use conventions?
   - **Recommendation**: Create lightweight registry for UI discovery

3. **Audit retention per section**: Different retention periods for different data types?
   - **Recommendation**: Defer to Phase 2, start with uniform 180 days

4. **Renewal period customization**: Should roles have configurable default renewal periods?
   - **Recommendation**: Defer to Phase 2, start with fixed 30 days

## Risks and Mitigation

### Risk: Permission cache invalidation issues
- **Impact**: Users retain/lose permissions incorrectly
- **Mitigation**: Comprehensive test coverage, monitoring of cache behavior
- **Fallback**: Temporarily disable caching if issues arise

### Risk: Expiration job failures
- **Impact**: Memberships don't expire or renew properly
- **Mitigation**: Robust error handling, retry logic, monitoring alerts
- **Fallback**: Manual membership management UI

### Risk: PaperTrail performance impact
- **Impact**: Slow writes to RBAC models
- **Mitigation**: Async version creation, database indexes
- **Fallback**: Disable tracking on low-priority models

### Risk: UI complexity overwhelming users
- **Impact**: Low adoption of new features
- **Mitigation**: Progressive disclosure, helpful tooltips, documentation
- **Fallback**: Simplified UI with fewer options

## Conclusion

This implementation plan provides a comprehensive roadmap for implementing granular metrics access control, time-based role assignments, and extensible section access management while addressing critical security vulnerabilities in the RBAC system. The phased approach allows for incremental delivery and testing, with clear rollback points at each phase.

The plan prioritizes security fixes and audit logging in early phases, followed by the core functionality for metrics access and time-based memberships, and concludes with UI enhancements for optimal user experience. By deferring complex features like conditional assignments and platform permission splitting, the plan maintains focus on delivering high-value functionality efficiently.

Total estimated effort: 160 hours over 6 weeks, with potential for parallel work streams to accelerate delivery.
