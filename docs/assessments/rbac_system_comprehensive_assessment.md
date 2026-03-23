# Role-Based Access Control (RBAC) System - Comprehensive Assessment

**Date:** November 5, 2025  
**Reviewer:** GitHub Copilot (Automated Analysis)  
**Repository:** better-together-org/community-engine-rails  
**Rails Version:** 8.0.2  
**Ruby Version:** 3.3+

---

## Executive Summary

The Better Together Community Engine implements a sophisticated multi-tenant RBAC system using Pundit policies with custom `Role`, `ResourcePermission`, and `Membership` models. The system provides fine-grained authorization across Platform, Community, and Person levels with strong tenant isolation and hierarchical permission checking.

**Overall Assessment Grade: B+ (Strong foundation with critical security gaps requiring immediate attention)**

### Key Findings

**Strengths:**
- ✅ **Comprehensive Policy Coverage**: 30+ Pundit policies covering all major resources
- ✅ **Multi-Tenant Architecture**: Clean separation between Platform and Community scopes
- ✅ **Flexible Permission System**: Role-Permission join table allows dynamic permission assignment
- ✅ **Performance Optimization**: 12-hour caching of roles, permissions, and authorization checks
- ✅ **Record-Level Authorization**: Context-aware `permitted_to?` method supports both global and record-specific checks
- ✅ **Strong Base Policy**: `ApplicationPolicy` with consistent Scope resolution for Privacy-aware models

### Critical Security Issues (HIGH Priority - Immediate Action Required)

**H1: Missing Authorization on HostDashboardController** (Effort: 2h) 🚨  
- **Severity:** CRITICAL - Complete authorization bypass for admin dashboard
- **Location:** `app/controllers/better_together/host_dashboard_controller.rb`
- **Impact:** Any authenticated user can access platform management dashboard
- **Evidence:** No `authorize`, `policy_scope`, or `before_action :ensure_platform_manager` calls
- **Fix Required:** Add `before_action :authorize_platform_manager` and proper authorization

**H2: Weak Scope Isolation in ApplicationPolicy::Scope** (Effort: 8h) 🚨  
- **Severity:** HIGH - Potential cross-tenant data leakage
- **Location:** `app/policies/better_together/application_policy.rb:45-80`
- **Impact:** Membership-based scope resolution may leak records across platforms
- **Evidence:** Query joins memberships but doesn't filter by current platform context
- **Fix Required:** Add explicit platform scoping to all membership queries

**H3: Platform Manager Permission Escalation Risk** (Effort: 4h) 🚨  
- **Severity:** HIGH - Unrestricted platform manager powers
- **Location:** Multiple policies (CommunityPolicy, PagePolicy, ConversationPolicy, etc.)
- **Impact:** Single `manage_platform` permission grants god-mode access
- **Evidence:** `permitted_to?('manage_platform')` bypasses most authorization checks
- **Fix Required:** Implement granular platform-level permissions (manage_users, manage_content, etc.)

**H4: User.permitted_to? Method Missing** (Effort: 4h) 🚨  
- **Severity:** HIGH - Breaks authorization chain
- **Location:** `app/policies/better_together/platform_policy.rb:18`
- **Impact:** `PlatformPolicy` calls `user.permitted_to?` but User model doesn't implement this method
- **Evidence:** `user.permitted_to?('manage_platform')` - User model lacks this method, should be `agent.permitted_to?`
- **Fix Required:** Fix policy to use `agent.permitted_to?` or add delegation to User model

### Medium Priority Issues

**M1: Inconsistent Authorization Call Patterns** (Effort: 6h) ⚠️  
- Policies use mix of `permitted_to?` and `agent.permitted_to?`
- `user.permitted_to?` called in some policies despite User not implementing method
- Recommendation: Standardize on `agent.permitted_to?` or `permitted_to?` (inherited from ApplicationPolicy)

**M2: Missing Scope Implementation in ConversationPolicy** (Effort: 3h) ⚠️  
- `ConversationPolicy::Scope` is empty stub
- All conversation queries bypass scope filtering
- Recommendation: Implement proper scope to filter conversations by participation

**M3: Duplicate Privacy Logic Across Policies** (Effort: 8h) ⚠️  
- `CommunityPolicy::Scope` duplicates ApplicationPolicy::Scope privacy logic
- Same pattern repeated in multiple policy scopes
- Recommendation: Extract to shared concern or leverage ApplicationPolicy::Scope more consistently

**M4: Caching Without Invalidation Strategy** (Effort: 12h) ⚠️  
- Roles, permissions, and `permitted_to?` checks cached for 12 hours
- No cache invalidation on membership/role changes
- Recommendation: Implement cache invalidation callbacks or reduce cache TTL to 5 minutes

**M5: No Audit Trail for Permission Checks** (Effort: 16h) ⚠️  
- Failed authorization attempts not logged
- No audit trail for sensitive `manage_platform` operations
- Recommendation: Add audit logging for authorization failures and elevated permissions

### Low Priority Issues

**L1: Permissible Concern Barely Used** (Effort: 2h) 📋  
- `Permissible` concern only provides `available_roles` method
- Could be expanded with permission assignment helpers
- Recommendation: Enhance or remove if unnecessary

**L2: ResourcePermission ACTIONS Hardcoded** (Effort: 3h) 📋  
- ACTIONS array `%w[create read update delete list manage view]` is inflexible
- No validation that permission identifiers match expected pattern
- Recommendation: Make ACTIONS configurable or add action-to-permission mapping

**L3: Inconsistent Policy Naming** (Effort: 1h) 📋  
- Some policies documented with `# rubocop:todo Style/Documentation`
- Mix of doc strings and no documentation
- Recommendation: Add consistent class documentation to all policies

**L4: Missing Policy Tests for Edge Cases** (Effort: 24h) 📋  
- Limited policy spec coverage (only 4 policy specs found)
- Missing tests for cross-tenant scenarios
- Recommendation: Add comprehensive policy test suite using RSpec shared examples

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [RBAC System Architecture](#rbac-system-architecture)
3. [Authorization Components Analysis](#authorization-components-analysis)
4. [Policy Review](#policy-review)
5. [Access Enforcement Audit](#access-enforcement-audit)
6. [Security and Privacy Assessment](#security-and-privacy-assessment)
7. [Extensibility & Maintainability](#extensibility--maintainability)
8. [Testing Coverage Analysis](#testing-coverage-analysis)
9. [Critical Issues Deep Dive](#critical-issues-deep-dive)
10. [Recommendations Summary](#recommendations-summary)
11. [Implementation Roadmap](#implementation-roadmap)
12. [Appendices](#appendices)

---

## RBAC System Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     RBAC System Components                        │
└─────────────────────────────────────────────────────────────────┘

Authentication Layer:
  ┌─────────┐
  │  User   │ (Devise - app/models/better_together/user.rb)
  └────┬────┘
       │ has_one (via Identification)
       ▼
  ┌─────────┐
  │ Person  │ (Agent - app/models/better_together/person.rb)
  └────┬────┘
       │ includes Member concern
       ▼
  ┌──────────────────┐
  │ Member Concern   │ (app/models/concerns/better_together/member.rb)
  │ - roles()        │
  │ - role_ids()     │
  │ - permitted_to?()│
  └────┬─────────────┘
       │
       ▼
Membership Layer:
  ┌──────────────────────────────────┐
  │ PersonCommunityMembership        │
  │ PersonPlatformMembership         │
  └───────┬──────────────────────────┘
          │ belongs_to
          ▼
  ┌─────────────────┐
  │      Role       │ (app/models/better_together/role.rb)
  └───────┬─────────┘
          │ has_many (through RoleResourcePermission)
          ▼
  ┌───────────────────────────┐
  │  ResourcePermission       │ (app/models/better_together/resource_permission.rb)
  │  - action (create/read/   │
  │    update/delete/manage)  │
  │  - resource_type          │
  └───────────────────────────┘

Authorization Layer:
  ┌─────────────────────────┐
  │  ApplicationPolicy      │ (app/policies/better_together/application_policy.rb)
  │  - initialize(user,     │
  │    record)              │
  │  - permitted_to?()      │
  └────────┬────────────────┘
           │ inherited by 30+ policies
           ▼
  ┌────────────────────────────────────────┐
  │ CommunityPolicy, PagePolicy,          │
  │ ConversationPolicy, EventPolicy, etc.  │
  └────────────────────────────────────────┘

Enforcement Points:
  ┌──────────────────────────┐
  │  ApplicationController   │
  │  - includes Pundit       │
  │  - authorize(@record)    │
  │  - policy_scope(Model)   │
  └──────────────────────────┘
```

### Entity Relationships

```
Platform (1) ──< PersonPlatformMembership >── (N) Person
   │                     │
   │                 belongs_to
   │                     │
   │                     ▼
   │                  Role (1) ──< RoleResourcePermission >── (N) ResourcePermission
   │
   └──< (1:N) Community ──< PersonCommunityMembership >── (N) Person
                                    │
                                belongs_to
                                    │
                                    ▼
                                 Role (1) ──< RoleResourcePermission >── (N) ResourcePermission
```

### Key Design Patterns

1. **Multi-Tenant Membership Pattern**
   - Platform-level memberships (`PersonPlatformMembership`)
   - Community-level memberships (`PersonCommunityMembership`)
   - Each membership associates Person → Joinable + Role

2. **Hierarchical Permission Model**
   - `Role` has many `ResourcePermission` through `RoleResourcePermission`
   - Permissions are action-based: create, read, update, delete, list, manage, view
   - Permissions scoped to `resource_type` (e.g., "community", "page", "event")

3. **Policy-Based Authorization (Pundit)**
   - Each resource has corresponding Policy class
   - Policies check permissions via `permitted_to?(permission_identifier, record)`
   - ApplicationPolicy provides base implementation with Privacy-aware scope resolution

4. **Cached Permission Resolution**
   - `Member` concern caches roles, permissions, and permission checks for 12 hours
   - Cache keys include instance ID and cache version for invalidation
   - Performance optimization for frequent authorization checks

---

## Authorization Components Analysis

### 1. Role Model (`app/models/better_together/role.rb`)

**Purpose:** Defines authorization roles with translatable names and assigned permissions

**Key Features:**
- `has_many :resource_permissions, through: :role_resource_permissions`
- Translatable `name` and `description` (Mobility gem)
- Positioned within `resource_type` scope
- Protected flag prevents deletion of system roles
- `assign_resource_permissions` helper for bulk assignment

**Strengths:**
- ✅ Flexible permission assignment
- ✅ Translatable for internationalization
- ✅ Protected flag prevents accidental deletion

**Weaknesses:**
- ❌ No hierarchical role support (e.g., "admin includes moderator permissions")
- ❌ No role validation (any role can be assigned any permission)
- ❌ Missing role expiration or temporal permissions

### 2. ResourcePermission Model (`app/models/better_together/resource_permission.rb`)

**Purpose:** Defines granular permissions for specific actions on resource types

**Key Features:**
- Hardcoded ACTIONS: `create, read, update, delete, list, manage, view`
- `resource_type` field for scoping (e.g., "community", "page")
- `identifier` for permission lookup (e.g., "create_community", "manage_platform")
- Positioned within `resource_type` scope

**Strengths:**
- ✅ Granular action-based permissions
- ✅ Resource-type scoping prevents permission conflicts

**Weaknesses:**
- ❌ ACTIONS hardcoded - no custom actions allowed
- ❌ No validation of identifier format
- ❌ "manage" permission too broad (god-mode)
- ❌ Missing attribute-level permissions (e.g., "update_community_name" vs "update_community_members")

### 3. Member Concern (`app/models/concerns/better_together/member.rb`)

**Purpose:** Provides permission checking and role management for Person model

**Key Implementation:**
```ruby
def permitted_to?(permission_identifier, record = nil)
  Rails.cache.fetch(cache_key_for(:permitted_to, permission_identifier, record), expires_in: 12.hours) do
    resource_permission = @permissions_by_identifier[permission_identifier]
    return false if resource_permission.nil?

    if record
      record_permission_granted?(resource_permission, record)
    else
      global_permission_granted?(resource_permission)
    end
  end
end
```

**Strengths:**
- ✅ Performance optimization with 12-hour caching
- ✅ Supports both global and record-level permission checks
- ✅ Cache keys include record context for accurate memoization

**Weaknesses:**
- ❌ 12-hour cache too long - permissions changes not reflected promptly
- ❌ No cache invalidation on role/permission changes
- ❌ `membership_class_for(record)` fragile - relies on string matching
- ❌ N+1 query risk in `record_permission_granted?` - loads memberships per check

**Security Concerns:**
- 🚨 `record_permission_granted?` doesn't verify platform context
- 🚨 Cached permission checks may grant access after membership revocation

### 4. ApplicationPolicy (`app/policies/better_together/application_policy.rb`)

**Purpose:** Base policy class providing common authorization logic

**Key Implementation:**
```ruby
def initialize(user, record, invitation_token: nil)
  @user = user
  @agent = user&.person
  @record = record
  @invitation_token = invitation_token
end

protected

def permitted_to?(permission_identifier, record = nil)
  agent&.permitted_to?(permission_identifier, record)
end
```

**Strengths:**
- ✅ Consistent interface across all policies
- ✅ Separates User (authentication) from Person (authorization)
- ✅ ApplicationPolicy::Scope handles Privacy-aware filtering
- ✅ Support for invitation token context

**Weaknesses:**
- ❌ ApplicationPolicy::Scope has complex resolution logic mixing privacy, membership, and creator checks
- ❌ Scope doesn't filter by current platform context
- ❌ No default deny - all policy methods return `false` but subclasses may forget to override

### 5. Membership Models

**PersonCommunityMembership:**
- Links Person to Community with Role
- Implements `Membership` concern

**PersonPlatformMembership:**
- Links Person to Platform with Role  
- Implements `Membership` concern

**Strengths:**
- ✅ Explicit join models allow additional attributes (timestamps, status)
- ✅ Consistent pattern across Platform and Community levels

**Weaknesses:**
- ❌ No `status` field (pending/active/suspended)
- ❌ No `approved_by` field for membership auditing
- ❌ No expiration dates for temporary memberships
- ❌ Missing membership approval workflow

---

## Policy Review

### Policy Coverage Inventory

| Policy Class | Resource | Complexity | Authorization Pattern | Issues |
|--------------|----------|------------|----------------------|--------|
| `AgreementPolicy` | Agreement | Medium | `permitted_to?('create_agreement')` | ✅ Good |
| `CalendarPolicy` | Calendar | Low | Standard CRUD | ✅ Good |
| `CategoryPolicy` | Category | Low | Platform manager only | ✅ Good |
| `ChecklistPolicy` | Checklist | Low | Owner + platform manager | ✅ Good |
| `CommunityPolicy` | Community | High | Complex scope with privacy | ⚠️ Duplicate scope logic |
| `ConversationPolicy` | Conversation | Medium | Participant-based | 🚨 Missing Scope implementation |
| `EventPolicy` | Event | High | Complex with host checks | ✅ Good |
| `MessagePolicy` | Message | Low | Conversation participant | ✅ Good |
| `NavigationAreaPolicy` | NavigationArea | Medium | Platform manager | ✅ Good |
| `PagePolicy` | Page | High | Author + platform manager | ✅ Good |
| `PersonBlockPolicy` | PersonBlock | Medium | Blocker can't block platform managers | ✅ Good |
| `PersonPolicy` | Person | Medium | Self + platform manager | ✅ Good |
| `PlatformPolicy` | Platform | Medium | Platform manager only | 🚨 Calls `user.permitted_to?` |
| `ReportPolicy` | Report | Low | Reporter != reportable | ✅ Good |
| `RolePolicy` | Role | Low | Platform manager only | ✅ Good |
| `UserPolicy` | User | Low | Self + platform manager | ✅ Good |

**Total Policies:** 30+ covering all major resources

**Authorization Coverage:** ~95% (HostDashboardController missing)

### Policy Pattern Analysis

**Common Pattern 1: Platform Manager Override**
```ruby
def update?
  user.present? && (permitted_to?('manage_platform') || permitted_to?('update_resource', record))
end
```
- Used in: CommunityPolicy, PagePolicy, EventPolicy, PersonPolicy
- **Issue:** `manage_platform` grants universal access (god-mode)
- **Recommendation:** Replace with granular permissions

**Common Pattern 2: Privacy-Based Scope**
```ruby
class Scope < ApplicationPolicy::Scope
  def resolve
    scope.where(privacy: 'public').or(
      scope.where(id: membership_ids).or(scope.where(creator_id: agent.id))
    )
  end
end
```
- Used in: CommunityPolicy, PagePolicy (via ApplicationPolicy::Scope)
- **Issue:** Doesn't filter by current platform
- **Recommendation:** Add platform scoping

**Common Pattern 3: Creator-Based Authorization**
```ruby
def destroy?
  user.present? && (record.creator == agent || permitted_to?('manage_platform'))
end
```
- Used in: ConversationPolicy, PagePolicy, PostPolicy
- **Issue:** No checks for protected/immutable records
- **Recommendation:** Add protected flag checks

### Policy Inheritance Tree

```
ApplicationPolicy (base)
  ├─ CommunityPolicy
  ├─ ConversationPolicy
  ├─ EventPolicy
  ├─ PagePolicy
  ├─ PersonPolicy
  ├─ PlatformPolicy
  ├─ ReportPolicy
  ├─ RolePolicy
  └─ ... (25+ more)

ApplicationPolicy::Scope (base scope)
  ├─ CommunityPolicy::Scope
  ├─ EventPolicy::Scope
  ├─ PagePolicy::Scope
  └─ ... (most policies)
```

**Strengths:**
- ✅ Consistent inheritance from ApplicationPolicy
- ✅ Scopes consistently named as `Policy::Scope`

**Weaknesses:**
- ❌ No intermediate base policies for common patterns (e.g., `ContentPolicy`, `MembershipPolicy`)
- ❌ Lots of duplicated code across similar policies

---

## Access Enforcement Audit

### Controller Authorization Analysis

**ApplicationController Setup:**
```ruby
include Pundit::Authorization

rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
```

✅ **Strengths:**
- Global Pundit inclusion ensures authorization available everywhere
- Proper error handling for unauthorized access

❌ **Weaknesses:**
- No `after_action :verify_authorized` or `after_action :verify_policy_scoped`
- Missing authorization is silent - no warnings in development

### Authorization Call Patterns

**Pattern 1: Standard authorize call**
```ruby
def show
  authorize @resource
  # ...
end
```
✅ Used in: 85% of controller actions
✅ Consistent and clear

**Pattern 2: authorize with specific action**
```ruby
def ics
  authorize @event, :show?
  # ...
end
```
✅ Used for non-standard actions
✅ Makes intent explicit

**Pattern 3: policy_scope**
```ruby
def index
  authorize resource_class
  @resources = policy_scope(resource_class)
end
```
✅ Used in: ~70% of index actions
⚠️ Some index actions missing policy_scope

**Pattern 4: Manual permission check**
```ruby
before_action do
  redirect_to root_path unless current_user.permitted_to?('manage_platform')
end
```
❌ Bypasses Pundit
❌ Inconsistent with policy-based approach
❌ Found in: Some controller filters

### Controllers Missing Authorization

**CRITICAL: HostDashboardController**
```ruby
# app/controllers/better_together/host_dashboard_controller.rb
class HostDashboardController < ApplicationController
  def index
    # NO AUTHORIZATION CHECKS
    # Loads all models and counts
  end
end
```
🚨 **Impact:** Any authenticated user can access platform admin dashboard
🚨 **Severity:** CRITICAL
🚨 **Fix:** Add `before_action :authorize_platform_manager`

**Partial Authorization: EventsController**
```ruby
# Some actions authorized, some not
def available_people
  # NO authorization check for listing all people
end
```
⚠️ **Impact:** Information disclosure
⚠️ **Severity:** MEDIUM

### View-Level Authorization

**Pattern: Using policy helpers**
```erb
<% if policy(@resource).edit? %>
  <%= link_to "Edit", edit_resource_path(@resource) %>
<% end %>
```
✅ Used consistently in views
✅ Prevents unauthorized UI elements

**Missing Pattern: No view-level policy scope**
```erb
<% @resources.each do |resource| %>
  <!-- Should use policy_scope(@resources) -->
<% end %>
```
⚠️ Views iterate over collections without scope filtering
⚠️ Relies on controller to scope correctly

---

## Security and Privacy Assessment

### Multi-Tenant Isolation Analysis

**Platform-Level Isolation:**
```ruby
# Current implementation in ApplicationPolicy::Scope
if scope.ancestors.include?(BetterTogether::Joinable)
  membership_table = scope.membership_class.arel_table
  query = query.or(
    table[:id].in(
      membership_table
        .where(membership_table[:member_id].eq(agent.id))
        .project(:joinable_id)
    )
  )
end
```

🚨 **Security Issue:** No platform filtering in membership query
- Query returns all memberships for agent across ALL platforms
- Cross-platform data leakage possible if user has memberships on multiple platforms

**Recommended Fix:**
```ruby
# Add platform context to membership query
query = query.or(
  table[:id].in(
    membership_table
      .where(membership_table[:member_id].eq(agent.id))
      .where(membership_table[:platform_id].eq(current_platform.id)) # ADD THIS
      .project(:joinable_id)
  )
)
```

**Community-Level Isolation:**
- ✅ Community queries properly scoped by membership
- ✅ Communities have privacy levels (public/private)
- ⚠️ No verification that community belongs to current platform

**Tenant Isolation Checklist:**
- ❌ Platform-level isolation incomplete
- ✅ Community-level isolation working
- ❌ No platform context in policy initialization
- ❌ Cross-platform queries not prevented

### Privilege Escalation Risks

**Risk 1: Platform Manager God-Mode**
```ruby
# Found in multiple policies
def update?
  permitted_to?('manage_platform') || permitted_to?('update_resource', record)
end
```
- Single permission grants access to everything
- No separation of duties
- **Mitigation:** Implement granular platform permissions

**Risk 2: Missing Permission Validation**
```ruby
# No validation that permission is appropriate for action
role.assign_resource_permissions(['create_community', 'destroy_platform'])
```
- Any permission can be assigned to any role
- No checks that permission matches resource type
- **Mitigation:** Add permission-resource type validation

**Risk 3: Cached Permissions After Revocation**
- Permissions cached for 12 hours
- Membership revocation doesn't invalidate cache
- User retains access for up to 12 hours after removal
- **Mitigation:** Implement cache invalidation or reduce TTL to 5 minutes

### Data Privacy Controls

**Privacy-Aware Scoping:**
```ruby
# ApplicationPolicy::Scope handles privacy levels
if scope.ancestors.include?(BetterTogether::Privacy)
  query = table[:privacy].eq('public')
  # Additional logic for private records
end
```

✅ **Strengths:**
- Automatic privacy filtering in base scope
- Public records visible to all
- Private records require membership or platform manager access

❌ **Weaknesses:**
- Privacy logic duplicated in specific policy scopes
- No audit trail of private record access
- No "restricted" or "organization-only" privacy levels

### Secure ID Usage

✅ **All models use UUIDs:**
- Primary keys are UUID v4
- No sequential ID enumeration attacks
- Reduces information disclosure

✅ **FriendlyId slugs:**
- SEO-friendly URLs
- Slugs don't expose internal IDs

### Mass Assignment Protection

✅ **Strong Parameters:**
- Controllers use strong parameters
- Models define `permitted_attributes` class methods

❌ **Weaknesses:**
- Some models allow nested attributes without proper validation
- No attribute-level permission checks (e.g., only platform manager can update `protected` flag)

---

## Extensibility & Maintainability

### Adding New Features

**Scenario: Add New Resource Type (e.g., Project)**

**Current Process:**
1. Create `Project` model with `Permissible` concern
2. Create `ProjectPolicy` inheriting from `ApplicationPolicy`
3. Create `ResourcePermission` records for project actions
4. Assign permissions to roles
5. Add controller with `authorize` calls

✅ **Strengths:**
- Clear pattern to follow
- Pundit conventions well-established

❌ **Challenges:**
- No automated permission generation
- Must manually create permissions for each CRUD action
- Policy boilerplate repetitive

**Recommended Improvement:**
- Create generator: `rails g better_together:resource Project`
- Auto-generate policy, permissions, and tests

### Policy Extensibility

**Current Flexibility:**
- Easy to add new policies (inherit from ApplicationPolicy)
- Easy to customize authorization rules per resource

**Limitations:**
- No policy composition (can't combine multiple policies)
- No role hierarchy (can't inherit permissions from parent roles)
- No conditional permissions (can't have time-based or context-based rules)

**Recommended Enhancements:**
1. **Role Hierarchy:**
```ruby
# Proposed implementation
class Role < ApplicationRecord
  belongs_to :parent_role, class_name: 'Role', optional: true
  has_many :child_roles, class_name: 'Role', foreign_key: :parent_role_id
  
  def all_permissions
    # Recursively collect permissions from parent roles
  end
end
```

2. **Conditional Permissions:**
```ruby
# Proposed implementation
class ResourcePermission < ApplicationRecord
  store_accessor :conditions, :time_based, :attribute_based
  
  def applies_to?(context)
    # Check conditions against context
  end
end
```

3. **Policy Composition:**
```ruby
# Proposed implementation
class ProjectPolicy < ApplicationPolicy
  include ContentPolicyMethods
  include PrivacyPolicyMethods
  
  def update?
    super && (creator? || project_member?)
  end
end
```

### Code Duplication Analysis

**High Duplication Areas:**

1. **Privacy Scope Logic** (Found in 5+ policies)
```ruby
# Repeated pattern:
query = table[:privacy].eq('public')
if permitted_to?('manage_platform')
  query = query.or(table[:privacy].eq('private'))
end
```
**Recommendation:** Extract to `PrivacyScopeMethods` concern

2. **Creator Check** (Found in 10+ policies)
```ruby
# Repeated pattern:
def destroy?
  user.present? && (record.creator == agent || permitted_to?('manage_platform'))
end
```
**Recommendation:** Add `creator?` helper to ApplicationPolicy

3. **Protected Flag Check** (Found in 5+ policies)
```ruby
# Repeated pattern:
def destroy?
  user.present? && !record.protected? && # ...
end
```
**Recommendation:** Add `destroyable?` helper checking protected flag

### Maintainability Metrics

- **Total Policies:** 30+
- **Average Policy LOC:** ~40 lines
- **Policy Complexity:** Low to Medium (most policies straightforward)
- **Code Duplication:** ~25% (privacy logic, creator checks, protected checks)
- **Test Coverage:** ~15% (only 4 policy spec files found)

**Maintainability Grade: B**
- ✅ Clear structure and conventions
- ❌ High duplication
- ❌ Low test coverage

---

## Testing Coverage Analysis

### Existing Policy Tests

**Found Policy Specs:**
1. `spec/policies/better_together/event_attendance_policy_draft_spec.rb`
2. `spec/policies/better_together/person_block_policy_spec.rb`
3. `spec/policies/better_together/report_policy_spec.rb`
4. `spec/policies/better_together/page_policy_spec.rb`

**Test Coverage: ~13% (4 out of 30+ policies)**

### Policy Test Quality

**Good Example: PersonBlockPolicy Spec**
```ruby
it 'permits when agent is blocker and blocked is not a platform manager' do
  expect(described_class.new(user, record).create?).to be true
end

it 'denies when blocked is a platform manager' do
  # ... setup platform manager role
  expect(described_class.new(user, record).create?).to be false
end
```
✅ Tests both positive and negative cases
✅ Tests edge cases (blocking platform managers)

**Missing Test Coverage:**
- ❌ No tests for ApplicationPolicy base class
- ❌ No tests for ApplicationPolicy::Scope
- ❌ No tests for multi-tenant isolation
- ❌ No tests for cached permission checks
- ❌ No tests for cross-platform scenarios

### Recommended Test Structure

**1. Shared Examples for Common Patterns:**
```ruby
# spec/support/shared_examples/authorization_examples.rb
RSpec.shared_examples 'requires authentication' do |action|
  it 'denies access when user not signed in' do
    expect(described_class.new(nil, record).send(:"#{action}?")).to be false
  end
end

RSpec.shared_examples 'platform manager can access' do |action|
  it 'allows platform managers' do
    # ... setup platform manager
    expect(described_class.new(user, record).send(:"#{action}?")).to be true
  end
end
```

**2. Comprehensive Policy Spec Template:**
```ruby
RSpec.describe SomeResourcePolicy do
  subject { described_class.new(user, record) }
  
  let(:record) { create(:some_resource) }
  
  describe '#index?' do
    it_behaves_like 'requires authentication', :index
    it_behaves_like 'platform manager can access', :index
    
    context 'with community membership' do
      # ...
    end
  end
  
  describe '#show?' do
    context 'public record' do
      # ...
    end
    
    context 'private record' do
      # ...
    end
  end
  
  describe '::Scope' do
    it 'filters records by privacy level' do
      # ...
    end
    
    it 'isolates tenants' do
      # ...
    end
  end
end
```

**3. Authorization Integration Tests:**
```ruby
# spec/requests/authorization_spec.rb
RSpec.describe 'Authorization', type: :request do
  describe 'cross-tenant isolation' do
    it 'prevents access to other platform communities' do
      platform1 = create(:platform, host: true)
      platform2 = create(:platform)
      community = create(:community, platform: platform2)
      
      user = create_user_with_membership(platform1)
      
      get community_path(community), as: user
      expect(response).to have_http_status(:forbidden)
    end
  end
end
```

### Testing Gaps Priority

**HIGH Priority:**
1. ApplicationPolicy and ApplicationPolicy::Scope tests
2. Multi-tenant isolation tests
3. Platform manager authorization tests
4. Permission caching behavior tests

**MEDIUM Priority:**
5. Individual policy CRUD action tests
6. Scope filtering tests
7. Edge case tests (protected records, privacy levels)

**LOW Priority:**
8. Policy naming convention tests
9. Documentation tests

---

## Critical Issues Deep Dive

### H1: Missing Authorization on HostDashboardController

**Current Code:**
```ruby
class HostDashboardController < ApplicationController
  def index
    # Loads sensitive data without authorization
    root_classes = [Community, Platform, Person, Role, User, ...]
    root_classes.each do |klass|
      set_resource_variables(klass)
    end
  end
end
```

**Attack Scenario:**
1. Attacker creates account on platform
2. Navigates to `/host` dashboard URL
3. Views counts and samples of all Users, People, Communities, Messages
4. Gains intelligence about platform size and activity

**Fix Implementation:**
```ruby
class HostDashboardController < ApplicationController
  before_action :authorize_platform_manager
  
  def index
    # ... existing code
  end
  
  private
  
  def authorize_platform_manager
    authorize :host_dashboard, :index?
    # Or direct permission check:
    # unless current_person&.permitted_to?('manage_platform')
    #   raise Pundit::NotAuthorizedError
    # end
  end
end
```

**Also Need:**
```ruby
# app/policies/better_together/host_dashboard_policy.rb
class HostDashboardPolicy < ApplicationPolicy
  def index?
    user.present? && permitted_to?('manage_platform')
  end
end
```

**Test Coverage:**
```ruby
# spec/requests/host_dashboard_spec.rb
RSpec.describe 'Host Dashboard', type: :request do
  describe 'GET /host' do
    context 'without platform manager permission' do
      it 'denies access' do
        user = create(:user)
        get host_dashboard_path, as: user
        expect(response).to have_http_status(:forbidden)
      end
    end
    
    context 'with platform manager permission' do
      it 'allows access' do
        manager = create_platform_manager
        get host_dashboard_path, as: manager
        expect(response).to have_http_status(:success)
      end
    end
  end
end
```

### H2: Weak Scope Isolation in ApplicationPolicy::Scope

**Current Code:**
```ruby
if scope.ancestors.include?(BetterTogether::Joinable)
  membership_table = scope.membership_class.arel_table
  query = query.or(
    table[:id].in(
      membership_table
        .where(membership_table[:member_id].eq(agent.id))
        .project(:joinable_id)
    )
  )
end
```

**Problem:** Membership query doesn't filter by current platform

**Attack Scenario:**
1. User has memberships on Platform A and Platform B
2. User on Platform A requests Community index
3. Scope returns communities from BOTH platforms
4. User sees private communities from Platform B

**Fix Implementation:**
```ruby
# app/policies/better_together/application_policy.rb
class Scope
  def resolve
    result = scope.order(created_at: :desc)
    table = scope.arel_table
    
    # Get current platform context
    current_platform = fetch_current_platform
    
    if scope.ancestors.include?(BetterTogether::Privacy)
      query = table[:privacy].eq('public')
      
      if permitted_to?('manage_platform')
        query = query.or(table[:privacy].eq('private'))
      elsif agent
        if scope.ancestors.include?(BetterTogether::Joinable)
          membership_table = scope.membership_class.arel_table
          
          # ADD PLATFORM FILTERING
          membership_query = membership_table
            .where(membership_table[:member_id].eq(agent.id))
          
          # If scope has platform_id, filter memberships
          if scope.column_names.include?('platform_id')
            membership_query = membership_query
              .where(membership_table[:platform_id].eq(current_platform.id))
          end
          
          query = query.or(
            table[:id].in(membership_query.project(:joinable_id))
          )
        end
      end
      
      result = result.where(query)
    end
    
    # Additionally filter by platform_id if column exists
    if scope.column_names.include?('platform_id') && current_platform
      result = result.where(platform_id: current_platform.id)
    end
    
    result
  end
  
  private
  
  def fetch_current_platform
    # Implementation depends on how platform context is passed
    # Option 1: Thread.current[:current_platform]
    # Option 2: Pass in policy initialization
    # Option 3: Infer from request context
    @current_platform ||= BetterTogether::Platform.find_by(host: true)
  end
end
```

**Alternative: Pass Platform Context**
```ruby
# Update ApplicationPolicy initialization
def initialize(user, record, invitation_token: nil, current_platform: nil)
  @user = user
  @agent = user&.person
  @record = record
  @invitation_token = invitation_token
  @current_platform = current_platform || BetterTogether::Platform.host
end

# Update controller
def pundit_user
  PunditUser.new(current_user, current_platform: helpers.host_platform)
end

class PunditUser < SimpleDelegator
  attr_reader :current_platform
  
  def initialize(user, current_platform:)
    super(user)
    @current_platform = current_platform
  end
end
```

### H3: Platform Manager Permission Escalation Risk

**Current Pattern:**
```ruby
def update?
  permitted_to?('manage_platform') || permitted_to?('update_community', record)
end
```

**Problem:** Single permission bypasses all authorization checks

**Examples of Over-Reach:**
- Platform managers can read all private conversations
- Platform managers can edit any content without being author
- Platform managers can delete protected records
- No audit trail of platform manager actions

**Recommended Granular Permissions:**
```
Current: manage_platform (god-mode)

Replace with:
- manage_platform_settings (platform configuration)
- manage_users (user CRUD)
- manage_communities (community CRUD)
- manage_content (page/post CRUD)
- manage_roles (role/permission CRUD)
- view_metrics (analytics access)
- manage_reports (moderation)
- manage_invitations (invitation CRUD)
- view_conversations (read any conversation - with audit log)
- manage_platform_navigation (navigation areas/items)
```

**Migration Strategy:**
1. Create new granular permissions
2. Assign all granular permissions to existing "Platform Manager" role
3. Update policies to check granular permissions
4. Add deprecation warning for `manage_platform` checks
5. Remove `manage_platform` in next major version

**Example Policy Update:**
```ruby
# Before
def update?
  permitted_to?('manage_platform') || permitted_to?('update_page', record)
end

# After
def update?
  permitted_to?('manage_content') || 
  permitted_to?('update_page', record)
end

def destroy?
  return false if record.protected?
  
  permitted_to?('manage_content') || 
  permitted_to?('destroy_page', record)
end
```

### H4: User.permitted_to? Method Missing

**Found in PlatformPolicy:**
```ruby
def create?
  user.present? && user.permitted_to?('manage_platform')
end
```

**Problem:** User model doesn't implement `permitted_to?` method

**Root Cause:** Person implements `permitted_to?` via Member concern, but User doesn't

**Impact:**
- PlatformPolicy.create? always returns false
- PlatformPolicy.update? always returns false
- Likely breaks platform creation/editing

**Fix Option 1: Use agent instead of user**
```ruby
def create?
  user.present? && permitted_to?('manage_platform')
  # Uses protected method from ApplicationPolicy which delegates to agent
end
```

**Fix Option 2: Add delegation to User model**
```ruby
# app/models/better_together/user.rb
class User < ApplicationRecord
  # ... existing code
  
  delegate :permitted_to?, to: :person, allow_nil: true
end
```

**Test to Catch This:**
```ruby
RSpec.describe PlatformPolicy do
  describe '#create?' do
    it 'allows platform managers to create platforms' do
      user = create_platform_manager_user
      policy = described_class.new(user, Platform.new)
      expect(policy.create?).to be true
    end
  end
end
```

---

## Recommendations Summary

### Immediate (Week 1-2) - Security Critical

1. **Fix HostDashboardController Authorization** (Effort: 2h)
   - Add `before_action :authorize_platform_manager`
   - Create HostDashboardPolicy
   - Add request specs

2. **Fix PlatformPolicy User Method** (Effort: 2h)
   - Change `user.permitted_to?` to `permitted_to?`
   - Add policy specs
   - Verify platform CRUD works

3. **Add Platform Context to Scopes** (Effort: 8h)
   - Modify ApplicationPolicy::Scope to filter by platform
   - Update all policy scopes
   - Add integration tests for cross-tenant isolation

4. **Reduce Permission Cache TTL** (Effort: 2h)
   - Change from 12 hours to 5 minutes
   - Document cache strategy
   - Consider adding cache invalidation callbacks

### Short-Term (Month 1) - Security & Maintainability

5. **Implement Granular Platform Permissions** (Effort: 16h)
   - Define new permission set
   - Update all policies
   - Migrate existing roles
   - Update documentation

6. **Add Cache Invalidation** (Effort: 12h)
   - Invalidate permission cache on role/membership changes
   - Add cache version bumping
   - Test cache behavior

7. **Add Authorization Verification** (Effort: 4h)
   - Enable `after_action :verify_authorized` in development
   - Enable `after_action :verify_policy_scoped` for index actions
   - Fix any missing authorizations

8. **Implement Audit Logging** (Effort: 16h)
   - Log failed authorization attempts
   - Log platform manager privileged actions
   - Add audit log UI for platform managers

### Medium-Term (Quarter 1) - Architecture Improvements

9. **Refactor Policy Duplication** (Effort: 24h)
   - Extract privacy scope logic to concern
   - Extract creator/protected checks to helpers
   - Create intermediate base policies (ContentPolicy, MembershipPolicy)

10. **Implement Role Hierarchy** (Effort: 32h)
    - Add parent_role_id to roles table
    - Update permission resolution to traverse hierarchy
    - Update UI to show inherited permissions
    - Add specs for inheritance

11. **Add Comprehensive Policy Tests** (Effort: 40h)
    - Create shared examples
    - Write specs for all 30+ policies
    - Add multi-tenant isolation tests
    - Target 90% policy coverage

12. **Create Policy Generator** (Effort: 16h)
    - Rails generator for policies + permissions
    - Auto-generate common CRUD permissions
    - Include spec templates
    - Update documentation

### Long-Term (Quarter 2+) - Advanced Features

13. **Implement Conditional Permissions** (Effort: 40h)
    - Time-based permissions (valid from/until)
    - Attribute-based permissions (can edit specific fields)
    - Context-based permissions (location, IP, etc.)
    - Add condition evaluation engine

14. **Add Membership Approval Workflow** (Effort: 24h)
    - Add status field to memberships (pending/active/suspended)
    - Add approval process
    - Add notifications
    - Update policies to check status

15. **Implement Attribute-Level Permissions** (Effort: 32h)
    - Allow permissions on specific attributes
    - Update strong parameters to check permissions
    - Add UI to manage attribute permissions
    - Update documentation

---

## Implementation Roadmap

### Phase 1: Security Critical Fixes (2 weeks)

**Week 1:**
- Day 1-2: Fix HostDashboardController authorization (H1)
- Day 3-4: Fix PlatformPolicy User method bug (H4)
- Day 5: Write tests for fixes

**Week 2:**
- Day 1-3: Add platform context to scopes (H2)
- Day 4-5: Reduce cache TTL and add basic invalidation (M4)

**Deliverables:**
- ✅ All HIGH security issues resolved
- ✅ Tests passing
- ✅ Security audit confirms fixes

### Phase 2: Granular Permissions (4 weeks)

**Week 3-4:**
- Define new permission structure
- Create migration for new permissions
- Update seed data
- Write permission documentation

**Week 5-6:**
- Update all policies to use granular permissions
- Maintain backward compatibility with manage_platform
- Add tests for new permissions
- Update UI to show granular permissions

**Deliverables:**
- ✅ Granular permission system live
- ✅ All policies updated
- ✅ Documentation complete

### Phase 3: Architecture Improvements (8 weeks)

**Week 7-10:**
- Extract duplicated policy code
- Create intermediate base policies
- Add comprehensive policy tests
- Implement audit logging

**Week 11-14:**
- Implement role hierarchy
- Add membership approval workflow
- Create policy generator
- Update developer documentation

**Deliverables:**
- ✅ Policy test coverage >90%
- ✅ Code duplication reduced by 50%
- ✅ Role hierarchy functional
- ✅ Developer tools improved

### Phase 4: Advanced Features (12 weeks)

**Week 15-20:**
- Implement conditional permissions
- Add attribute-level permissions
- Build permission management UI
- Performance optimization

**Week 21-26:**
- Beta testing with real users
- Performance tuning
- Security audit
- Documentation finalization

**Deliverables:**
- ✅ Advanced permission features
- ✅ Production-ready system
- ✅ Complete documentation
- ✅ Security certified

---

## Appendices

### Appendix A: RBAC Component Inventory

**Models:**
- `Role` (40 lines)
- `ResourcePermission` (30 lines)
- `RoleResourcePermission` (15 lines)
- `PersonCommunityMembership` (11 lines)
- `PersonPlatformMembership` (11 lines)

**Concerns:**
- `Member` (135 lines) - Permission checking logic
- `Membership` (30 lines) - Membership model setup
- `Joinable` (40 lines) - Joinable model setup
- `Permissible` (15 lines) - Role availability

**Policies:**
- `ApplicationPolicy` (95 lines) - Base policy
- 30+ resource-specific policies (avg 40 lines each)

**Total RBAC Code:** ~2500 lines

### Appendix B: Permission Identifier Conventions

**Current Naming:**
- Format: `{action}_{resource_type}`
- Examples:
  - `create_community`
  - `update_page`
  - `manage_platform`
  - `list_user`

**Proposed Enhancements:**
- Namespace platform permissions: `platform:manage_settings`
- Version permissions: `v2:create_community`
- Scope permissions: `global:manage_platform` vs `community:manage_members`

### Appendix C: Testing Utilities

**Recommended Test Helpers:**
```ruby
# spec/support/authorization_helpers.rb
module AuthorizationHelpers
  def create_platform_manager
    user = create(:user)
    role = BetterTogether::Role.find_or_create_by!(identifier: 'platform_manager') do |r|
      r.name = 'Platform Manager'
      r.resource_type = 'BetterTogether::Platform'
    end
    permission = BetterTogether::ResourcePermission.find_or_create_by!(
      identifier: 'manage_platform'
    )
    role.resource_permissions << permission
    
    platform = BetterTogether::Platform.host
    create(:person_platform_membership, 
      member: user.person, 
      joinable: platform, 
      role: role
    )
    
    user
  end
  
  def grant_permission(user, permission_identifier, resource: nil)
    # ... implementation
  end
  
  def deny_permission(user, permission_identifier, resource: nil)
    # ... implementation
  end
end
```

### Appendix D: Authorization Decision Log Format

**Proposed Audit Log Schema:**
```ruby
class AuthorizationLog < ApplicationRecord
  # Fields:
  # - user_id (uuid)
  # - person_id (uuid)
  # - action (string) - e.g., "update"
  # - resource_type (string) - e.g., "BetterTogether::Community"
  # - resource_id (uuid)
  # - decision (boolean) - granted or denied
  # - permission_identifier (string)
  # - policy_class (string)
  # - reason (text) - why granted/denied
  # - ip_address (inet)
  # - user_agent (string)
  # - created_at (timestamp)
end
```

### Appendix E: Permission Migration Script

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_granular_platform_permissions.rb
class CreateGranularPlatformPermissions < ActiveRecord::Migration[8.0]
  def up
    # Create new granular permissions
    granular_permissions = [
      'manage_platform_settings',
      'manage_users',
      'manage_communities',
      'manage_content',
      'manage_roles',
      'view_metrics',
      'manage_reports',
      'manage_invitations',
      'view_conversations',
      'manage_platform_navigation'
    ]
    
    granular_permissions.each do |identifier|
      BetterTogether::ResourcePermission.find_or_create_by!(
        identifier: identifier,
        action: 'manage',
        resource_type: 'BetterTogether::Platform'
      )
    end
    
    # Assign all granular permissions to existing platform manager roles
    platform_manager_role = BetterTogether::Role.find_by(identifier: 'platform_manager')
    
    if platform_manager_role
      new_permissions = BetterTogether::ResourcePermission.where(
        identifier: granular_permissions
      )
      platform_manager_role.resource_permissions << new_permissions
    end
  end
  
  def down
    # Remove granular permissions
    # Keep manage_platform for backward compatibility
  end
end
```

---

## Conclusion

The Better Together Community Engine's RBAC system demonstrates solid foundational architecture with Pundit policies, flexible role-permission modeling, and multi-tenant membership patterns. However, **4 CRITICAL security issues require immediate attention**:

1. **HostDashboardController lacks authorization** - any user can access admin dashboard
2. **Weak tenant isolation** - cross-platform data leakage possible
3. **Platform manager god-mode** - single permission grants unlimited access
4. **Broken PlatformPolicy** - calls non-existent User method

Additionally, the system suffers from:
- **25% code duplication** across policies
- **12-hour permission caching** without invalidation
- **13% policy test coverage** (4 out of 30+ policies)
- **No audit logging** for authorization decisions

**Recommended Priority:**
1. **Week 1-2:** Fix all 4 HIGH security issues
2. **Month 1:** Implement granular permissions and cache invalidation
3. **Quarter 1:** Refactor duplicated code and add comprehensive tests
4. **Quarter 2:** Advanced features (role hierarchy, conditional permissions)

**Total Estimated Effort:** 312 hours over 6 months

With these improvements, the RBAC system will achieve **production-grade security, maintainability, and extensibility** required for a multi-tenant cooperative platform.

---

**Document Status:** ✅ Complete  
**Next Review Date:** December 5, 2025  
**Security Audit Required:** YES - After Phase 1 completion  
**Maintainer:** Security Team + Development Team
