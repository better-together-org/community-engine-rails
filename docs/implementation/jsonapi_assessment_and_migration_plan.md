# JSONAPI Implementation Assessment & Migration Plan

**Date:** January 27, 2026  
**Status:** Ready for Production Migration  
**Priority:** High

## Executive Summary

This document provides a comprehensive assessment of the current JSONAPI implementation in the Better Together Community Engine Rails application, including authentication mechanisms, resource serializers, Pundit policy alignment, and a detailed migration plan to move files from `future_*` directories to their production locations.

### Current State
- ✅ JSONAPI-Resources gem configured and integrated
- ✅ Base ApiResource and ApiController classes established
- ✅ Pundit integration for authorization
- ✅ Custom link builder for dynamic base URLs
- ⚠️ API routes currently commented out (security measure)
- ⚠️ Controllers and specs in `future_*` directories
- ⚠️ Resources need updates to match current model structure
- ⚠️ Missing comprehensive documentation

---

## Table of Contents

1. [Current JSONAPI Architecture](#current-jsonapi-architecture)
2. [Authentication Analysis](#authentication-analysis)
3. [Resource Serializer Assessment](#resource-serializer-assessment)
4. [Policy Alignment Review](#policy-alignment-review)
5. [Model Discrepancies](#model-discrepancies)
6. [Migration Plan](#migration-plan)
7. [Documentation Requirements](#documentation-requirements)
8. [Testing Strategy](#testing-strategy)
9. [Security Considerations](#security-considerations)
10. [Next Steps](#next-steps)

---

## 1. Current JSONAPI Architecture

### 1.1 Core Components

#### JSONAPI Configuration
**Location:** `config/initializers/jsonapi.rb`

```ruby
JSONAPI.configure do |config|
  config.json_key_format = :underscored_key
  config.route_format = :underscored_route
  config.top_level_meta_include_record_count = true
  config.top_level_meta_include_page_count = true
  config.exception_class_whitelist = %w[Pundit::NotAuthorizedError]
end
```

**Analysis:**
- ✅ Underscored key format (Rails convention)
- ✅ Pagination metadata enabled
- ✅ Pundit exceptions properly whitelisted
- ✅ Standard JSONAPI compliance

#### Base ApiResource
**Location:** `app/resources/better_together/api_resource.rb`

```ruby
class ApiResource < ::JSONAPI::Resource
  abstract
  include Pundit::Resource

  attributes :created_at, :updated_at
end
```

**Analysis:**
- ✅ Pundit integration for authorization
- ✅ Common timestamps included
- ✅ Abstract base class pattern
- ⚠️ Missing common i18n/translation handling
- ⚠️ No standardized identifier handling

#### Base ApiController
**Location:** `app/future_controllers/better_together/api_controller.rb`

```ruby
class ApiController < ::JSONAPI::ResourceController
  include Pundit::Authorization
  include Pundit::ResourceController

  protect_from_forgery with: :exception, unless: -> { request.format.json? }
end
```

**Analysis:**
- ✅ Pundit authorization integrated
- ✅ CSRF protection for non-JSON requests
- ✅ Inherits from JSONAPI::ResourceController
- ⚠️ Missing before_action for authentication
- ⚠️ No error handling customization

### 1.2 Custom Link Builder
**Location:** `lib/jsonapi/link_builder.rb`

**Purpose:** Handles dynamic base URL generation for multi-tenant engine routing

**Analysis:**
- ✅ Properly handles Rails engine mount points
- ✅ Supports dynamic base URLs
- ✅ Comprehensive error handling
- ✅ Route warning system in place
- 📝 **Coverage:** 27.6% (55 uncovered lines) - needs test coverage

---

## 2. Authentication Analysis

### 2.1 Current Authentication Mechanisms

#### JWT-Based Authentication (Devise)
**Implementation:** User model with `devise-jwt` strategy

```ruby
devise :jwt_authenticatable,
       jwt_revocation_strategy: JwtDenylist
```

**Features:**
- JWT tokens for stateless authentication
- Token revocation via JwtDenylist
- Database-backed denylist for security

#### Session-Based Authentication (Traditional Devise)
**Modules:** `:database_authenticatable`, `:registerable`, `:recoverable`, `:rememberable`, `:validatable`, `:confirmable`

### 2.2 Authentication Controllers

#### Sessions Controller
**Location:** `app/future_controllers/better_together/bt/api/auth/sessions_controller.rb`

```ruby
class SessionsController < Devise::SessionsController
  respond_to :json

  protected

  def respond_with(resource, _opts = {})
    render json: resource
  end

  def respond_to_on_destroy
    head :ok
  end
end
```

**Assessment:**
- ✅ JSON response format
- ⚠️ Returns raw user object (security risk - exposes all attributes)
- ❌ Missing JWT token in response
- ❌ No person data serialization
- ❌ No rate limiting

#### Registrations Controller
**Location:** `app/future_controllers/better_together/bt/api/registrations_controller.rb`

**Key Features:**
- Custom email confirmation URL support
- Nested person attributes
- Manual confirmation email control

**Critical Issues:**
```ruby
# ❌ SECURITY ISSUE: Returns raw resource
respond_with resource, location: after_sign_up_path_for(resource)

# ❌ INSUFFICIENT PERMISSIONS
devise_parameter_sanitizer.permit(:sign_up,
  keys: [:email, :password, :password_confirmation,
         { person_attributes: %i[name description] }])
```

**Missing Person Attributes:**
- `locale` (required for i18n)
- `time_zone` (required for timezone handling)
- `privacy` (critical for data protection)
- `identifier` (required for unique handles)

### 2.3 Authentication Gaps

1. **No JWT Token Response**
   - Sessions controller doesn't return JWT in response
   - Frontend apps can't store/use tokens
   - Requires custom Devise JWT response override

2. **Incomplete User Serialization**
   - Raw user objects expose all database columns
   - No person data in authentication responses
   - Missing required user context (roles, permissions, communities)

3. **Missing API-Specific Authentication**
   - No `authenticate_user!` before_action in base controller
   - Individual controllers must implement (inconsistent)
   - No unified authentication strategy

4. **Rate Limiting Absent**
   - No protection against brute force attacks
   - Registration spam vulnerability
   - No throttling on password reset

---

## 3. Resource Serializer Assessment

### 3.1 Existing Resources

#### CommunityResource
**Location:** `app/resources/better_together/bt/api/v1/community_resource.rb`

**Current Implementation:**
```ruby
attributes :name, :description, :slug, :creator_id

has_one :creator, class_name: 'Person'
```

**Model Attributes (from Community model):**
```ruby
# Translatable
translates :name, type: :string
translates :description, type: :text
translates :description_html, backend: :action_text

# Standard
- slug
- creator_id
- privacy (CRITICAL - missing)
- identifier (CRITICAL - missing)
- protected (boolean)
- host (boolean)

# Associations
- creator (Person)
- calendars
- invitations
- profile_image (Active Storage)
- cover_image (Active Storage)
- logo (Active Storage)
- person_community_memberships (through Joinable concern)
```

**❌ CRITICAL GAPS:**
1. Missing `privacy` attribute (security risk)
2. Missing `identifier` attribute (required for references)
3. Missing `protected` attribute (prevents deletion of critical communities)
4. No attachment handling (profile_image, cover_image, logo)
5. No translated attribute handling
6. Missing `has_many :members` relationship

**✅ CORRECT:**
- Base attributes present
- Creator relationship defined

#### PersonResource
**Location:** `app/resources/better_together/bt/api/v1/person_resource.rb`

**Current Implementation:**
```ruby
attributes :name, :description, :slug
```

**Model Attributes:**
```ruby
# Translatable
translates :description_html, backend: :action_text

# Standard
- name
- identifier (CRITICAL - missing)
- slug
- privacy (CRITICAL - missing)
- locale (preferences store)
- time_zone (preferences store)
- receive_messages_from_members (preferences store)
- notify_by_email (notification_preferences store)
- show_conversation_details (notification_preferences store)

# Virtual
- email (delegated to user or contact details)
- handle (alias for identifier)

# Associations
- user (through identification)
- communities (through memberships)
- conversations
- person_blocks
- blocked_people
- reports_made
- profile_image (Active Storage)
- cover_image (Active Storage)
```

**❌ CRITICAL GAPS:**
1. Missing `identifier` (required for @handle references)
2. Missing `privacy` (security risk)
3. Missing `email` (needed for user context)
4. Missing `locale` and `time_zone` (i18n/timezone requirements)
5. Missing preference attributes
6. No attachment handling
7. No relationships defined
8. Missing `handle` virtual attribute

#### RoleResource
**Location:** `app/resources/better_together/bt/api/v1/role_resource.rb`

**Current Implementation:**
```ruby
attributes :name, :description, :sort_order, :reserved
```

**Model Attributes:**
```ruby
# Translatable
translates :name, type: :string
translates :description, type: :text

# Standard
- identifier (missing)
- sort_order
- reserved (protected alias)
- protected
- position
- resource_type

# Associations
- resource_permissions (through role_resource_permissions)
```

**⚠️ MINOR GAPS:**
1. Using `reserved` instead of model's `protected` attribute
2. Missing `identifier`
3. Missing `resource_type`
4. Missing `position` (Positioned concern)
5. No relationships defined
6. No translated attribute handling

#### CommunityMembershipResource
**Location:** `app/resources/better_together/bt/api/v1/community_membership_resource.rb`

**Current Implementation:**
```ruby
has_one :member, class_name: 'Person'
has_one :community
has_one :role
```

**Model Structure:**
```ruby
# NOTE: Model is PersonCommunityMembership, not CommunityMembership
class PersonCommunityMembership < ApplicationRecord
  # Attributes
  - member_id (references Person)
  - joinable_id (references Community)
  - role_id
  - status (enum: pending, active)
  
  # Associations (through Membership concern)
  belongs_to :member, class_name: 'BetterTogether::Person'
  belongs_to :joinable, class_name: 'BetterTogether::Community'
  belongs_to :role, class_name: 'BetterTogether::Role'
end
```

**❌ CRITICAL ISSUES:**
1. **Wrong model name:** Resource references `CommunityMembership` but model is `PersonCommunityMembership`
2. Missing `status` attribute (critical for membership state)
3. No attributes defined (only relationships)
4. Missing timestamps
5. Resource may not function due to model name mismatch

#### UserResource
**Location:** `app/resources/better_together/bt/api/v1/user_resource.rb`

**Current Implementation:**
```ruby
attributes :email, :password, :password_confirmation
```

**❌ CRITICAL SECURITY ISSUES:**
1. **Password fields in resource** - passwords should NEVER be returned in API responses
2. Missing read-only protection on password fields
3. Missing `person` relationship
4. Missing confirmation status
5. Missing JWT token context

**Model Attributes:**
```ruby
- email
- encrypted_password (never expose)
- confirmed_at
- confirmation_sent_at
- reset_password_token
- reset_password_sent_at

# Associations
- person (through identification)
```

**Should Only Include:**
- `email` (readable)
- `confirmed` (boolean, virtual)
- `person` (relationship)

#### RegistrationResource
**Location:** `app/resources/better_together/bt/api/v1/registration_resource.rb`

**Current Implementation:**
```ruby
model_name '::BetterTogether::User'

attributes :email, :password, :password_confirmation
```

**❌ SAME SECURITY ISSUES AS UserResource**
- Passwords should not be readable
- Should be write-only resource
- Needs separate response resource

### 3.2 Missing Resources

Based on future_spec and controller analysis, these resources are needed but don't exist:

1. **SessionResource** - For authentication responses
2. **PasswordResource** - For password reset flows
3. **ConfirmationResource** - For email confirmation
4. **PersonPlatformMembershipResource** - For platform memberships
5. **InvitationResource** - For community/platform invitations

---

## 4. Policy Alignment Review

### 4.1 Policy-to-Controller Mapping

#### Community API Endpoints

**Policy:** `BetterTogether::CommunityPolicy`

| Action | Policy Method | Authentication | Notes |
|--------|--------------|----------------|-------|
| `index` | `index?` | ❌ Optional | Returns `true` (public listing) |
| `show` | `show?` | ⚠️ Complex | Public OR member OR creator OR platform_manager OR invitation |
| `create` | `create?` | ✅ Required | User present AND (platform_manager OR create_community permission) |
| `update` | `update?` | ✅ Required | User present AND (platform_manager OR update_community permission) |
| `destroy` | `destroy?` | ✅ Required | User present AND not protected AND not host AND permissions |

**Controller:** `app/future_controllers/better_together/bt/api/v1/communities_controller.rb`

```ruby
class CommunitiesController < BetterTogether::Api::ApplicationController
  before_action :authenticate_user!, except: %i[index]
end
```

**✅ ALIGNMENT:**
- Matches policy requirements
- Index publicly accessible
- All other actions require authentication

**⚠️ MISSING:**
- No explicit authorization calls (should use `authorize @community`)
- Scope filtering not implemented
- Policy's `view_members?` and `create_events?` methods unused

#### Person API Endpoints

**Policy:** `BetterTogether::PersonPolicy`

| Action | Policy Method | Authentication | Authorization |
|--------|--------------|----------------|---------------|
| `index` | `index?` | ✅ Required | User present AND `list_person` permission |
| `show` | `show?` | ✅ Required | User present AND (me? OR `read_person` permission) |
| `create` | `create?` | ✅ Required | User present AND `create_person` permission |
| `update` | `update?` | ✅ Required | User present AND (me? OR `update_person` permission) |
| `destroy` | `destroy?` | ✅ Required | User present AND `delete_person` permission |
| `me` | Custom | ✅ Required | Returns current user's person |

**Controller:** `app/future_controllers/better_together/bt/api/v1/people_controller.rb`

```ruby
class PeopleController < BetterTogether::Api::ApplicationController
  before_action :authenticate_user!

  def me
    @policy_used = person = authorize current_user.person
    render json: person.to_json
  end
end
```

**✅ ALIGNMENT:**
- Authentication required
- `me` action has authorization

**❌ CRITICAL ISSUES:**
1. Raw `to_json` response instead of JSONAPI resource
2. No authorization on standard CRUD actions
3. Missing scope filtering
4. Policy's complex privacy logic not utilized

**Policy Scope Complexity:**
```ruby
# Policy filters people based on:
# 1. Platform managers see all
# 2. Unauthenticated see only public
# 3. Authenticated see:
#    - Own profile
#    - Public profiles
#    - Shared community members (with community+ privacy)
#    - Direct interaction contacts
#    - EXCLUDING blocked/blocking users
```

**⚠️ RISK:** Without scope, API may expose private person records

#### Role API Endpoints

**Policy:** `BetterTogether::RolePolicy`

| Action | Policy Method | Authentication | Authorization |
|--------|--------------|----------------|---------------|
| `index` | `index?` | ✅ Required | User present |
| `show` | `show?` | ✅ Required | User present |
| `create` | `create?` | ❌ Forbidden | Always returns `false` |
| `update` | `update?` | ✅ Required | User present |
| `destroy` | `destroy?` | ✅ Required | User present AND not protected |

**Controller:** `app/future_controllers/better_together/bt/api/v1/roles_controller.rb`

```ruby
class RolesController < BetterTogether::Api::ApplicationController
  before_action :authenticate_user!
end
```

**✅ ALIGNMENT:**
- Authentication required
- Create forbidden in policy (roles are system-managed)

**⚠️ MISSING:**
- No authorization checks
- No scope implementation
- Protected role deletion prevention not enforced

#### PersonCommunityMembership (CommunityMembership) API Endpoints

**Policy:** `BetterTogether::PersonCommunityMembershipPolicy`

| Action | Policy Method | Authorization |
|--------|--------------|---------------|
| `create` | `create?` | User present AND `update_community` permission |
| `edit` | `edit?` | User present AND `update_community` permission |
| `destroy` | `destroy?` | User present AND not self AND `update_community` AND not platform_manager |

**Controller:** `app/future_controllers/better_together/bt/api/v1/community_memberships_controller.rb`

```ruby
class CommunityMembershipsController < BetterTogether::Api::ApplicationController
  before_action :authenticate_user!
end
```

**❌ CRITICAL ISSUES:**
1. Resource name mismatch (`CommunityMembership` vs `PersonCommunityMembership`)
2. No authorization checks
3. Policy prevents deleting self (but not enforced)
4. Policy prevents deleting platform managers (not enforced)
5. Notifications on create/update/destroy not considered

### 4.2 Authorization Implementation Gaps

**Current State:**
- Base `ApiController` includes `Pundit::Authorization` and `Pundit::ResourceController`
- Controllers require authentication via `before_action :authenticate_user!`
- **NO** controllers call `authorize` explicitly
- **NO** controllers use `policy_scope` for filtering

**Required Pattern:**

```ruby
class CommunitiesController < BetterTogether::Api::ApplicationController
  before_action :authenticate_user!, except: %i[index show]
  
  def index
    @communities = policy_scope(Community)
    render jsonapi: @communities
  end
  
  def show
    @community = Community.find(params[:id])
    authorize @community
    render jsonapi: @community
  end
  
  def create
    @community = Community.new(resource_params)
    authorize @community
    if @community.save
      render jsonapi: @community, status: :created
    else
      render jsonapi_errors: @community.errors, status: :unprocessable_entity
    end
  end
  
  # etc...
end
```

---

## 5. Model Discrepancies

### 5.1 Community Model vs Resource

**Resource Gaps:**

| Model Attribute/Relationship | In Resource? | Importance | Notes |
|------------------------------|--------------|------------|-------|
| `identifier` | ❌ | CRITICAL | Required for unique identification |
| `privacy` | ❌ | CRITICAL | Security - data protection |
| `protected` | ❌ | HIGH | Prevents deletion of system communities |
| `host` | ❌ | HIGH | Identifies platform host community |
| `profile_image` | ❌ | MEDIUM | Active Storage - needs special handling |
| `cover_image` | ❌ | MEDIUM | Active Storage |
| `logo` | ❌ | MEDIUM | Active Storage |
| Translation support | ❌ | HIGH | Mobility gem - needs locale handling |
| `has_many :members` | ❌ | HIGH | Critical relationship |
| `has_many :calendars` | ❌ | MEDIUM | Calendar integration |

**Recommended Resource Structure:**

```ruby
class CommunityResource < ::BetterTogether::ApiResource
  model_name '::BetterTogether::Community'

  # Translated attributes - need special handling
  attributes :name, :description
  
  # Standard attributes
  attributes :slug, :identifier, :privacy, :protected, :host
  
  # Virtual attributes for attachments
  attribute :profile_image_url
  attribute :cover_image_url
  attribute :logo_url
  
  # Relationships
  has_one :creator, class_name: 'Person'
  has_many :members, class_name: 'Person'
  has_many :calendars, class_name: 'Calendar'
  has_many :person_community_memberships
  
  # Filters
  filter :privacy
  filter :protected
  
  # Custom methods
  def profile_image_url
    return nil unless @model.profile_image.attached?
    Rails.application.routes.url_helpers.url_for(@model.profile_image)
  end
  
  # Similar for cover_image_url, logo_url
end
```

### 5.2 Person Model vs Resource

**Resource Gaps:**

| Model Attribute/Relationship | In Resource? | Importance | Notes |
|------------------------------|--------------|------------|-------|
| `identifier` | ❌ | CRITICAL | Used for @handle mentions |
| `privacy` | ❌ | CRITICAL | User privacy settings |
| `email` | ❌ | HIGH | Needed for user context |
| `locale` | ❌ | HIGH | I18n requirement |
| `time_zone` | ❌ | HIGH | Timezone handling |
| `receive_messages_from_members` | ❌ | MEDIUM | Privacy preference |
| `notify_by_email` | ❌ | MEDIUM | Notification preference |
| `show_conversation_details` | ❌ | MEDIUM | Notification preference |
| `profile_image` | ❌ | MEDIUM | Active Storage |
| `cover_image` | ❌ | MEDIUM | Active Storage |
| `has_one :user` | ❌ | HIGH | Critical relationship |
| `has_many :communities` | ❌ | HIGH | Member communities |
| `has_many :conversations` | ❌ | MEDIUM | Messaging |
| `has_many :person_blocks` | ❌ | MEDIUM | Safety feature |

**Recommended Resource Structure:**

```ruby
class PersonResource < ::BetterTogether::ApiResource
  model_name '::BetterTogether::Person'

  # Basic attributes
  attributes :name, :identifier, :slug, :privacy
  
  # Virtual attributes
  attribute :handle  # Alias for identifier
  attribute :email
  
  # Preferences
  attribute :locale
  attribute :time_zone
  attribute :receive_messages_from_members
  
  # Notification preferences
  attribute :notify_by_email
  attribute :show_conversation_details
  
  # Attachment URLs
  attribute :profile_image_url
  attribute :cover_image_url
  
  # Relationships
  has_one :user, class_name: 'User'
  has_many :communities, class_name: 'Community'
  has_many :person_community_memberships
  has_many :conversations
  has_many :person_blocks
  has_many :blocked_people, class_name: 'Person'
  
  # Filters
  filter :privacy
  filter :locale
  
  # Custom attribute methods
  def handle
    @model.identifier
  end
  
  def email
    @model.email
  end
  
  def locale
    @model.locale
  end
  
  def time_zone
    @model.time_zone
  end
  
  # etc...
end
```

### 5.3 Role Model vs Resource

**Minor Gaps:**

| Model Attribute | In Resource? | Notes |
|-----------------|--------------|-------|
| `identifier` | ❌ | Unique identifier |
| `protected` | ⚠️ | Resource uses `reserved` |
| `position` | ❌ | Ordering |
| `resource_type` | ❌ | Resource scoping |
| Translation support | ❌ | Mobility gem |

### 5.4 PersonCommunityMembership Model vs CommunityMembershipResource

**Critical Issues:**

| Issue | Impact | Fix Required |
|-------|--------|--------------|
| Model name mismatch | Resource won't find model | Rename resource OR update model_name |
| Missing `status` attribute | Can't filter pending/active | Add to attributes |
| No attributes defined | Only relationships returned | Add member_id, joinable_id, role_id, status |
| Notifications on lifecycle | Backend events won't fire | Ensure controller doesn't bypass model |

**Recommended Fix:**

```ruby
class PersonCommunityMembershipResource < ::BetterTogether::ApiResource
  model_name '::BetterTogether::PersonCommunityMembership'

  # Attributes
  attribute :status  # enum: pending, active
  
  # Relationships
  has_one :member, class_name: 'Person'
  has_one :joinable, class_name: 'Community'  # Or has_one :community, foreign_key: :joinable_id
  has_one :role
  
  # Filters
  filter :status
  filter :member_id
  filter :joinable_id
end
```

### 5.5 User Model vs UserResource

**Security Critical Issues:**

| Issue | Risk Level | Fix |
|-------|-----------|-----|
| Password fields in resource | CRITICAL | Remove from attributes, make write-only |
| No read-only protection | CRITICAL | Never return passwords |
| Missing person relationship | HIGH | Add has_one :person |
| Raw resource response in auth | HIGH | Use proper serializer |

**Recommended Fix:**

```ruby
class UserResource < ::BetterTogether::ApiResource
  model_name '::BetterTogether::User'

  # ONLY include safe attributes
  attributes :email
  attribute :confirmed  # Virtual boolean
  
  # Relationships
  has_one :person, class_name: 'Person'
  
  # Custom attribute
  def confirmed
    @model.confirmed_at.present?
  end
  
  # NEVER include: password, password_confirmation, encrypted_password,
  # reset_password_token, confirmation_token, etc.
end
```

---

## 6. Migration Plan

### Phase 1: Preparation (Pre-Migration)

#### 1.1 Update Base Classes

**File:** `app/resources/better_together/api_resource.rb`

**Changes:**
```ruby
class ApiResource < ::JSONAPI::Resource
  abstract
  include Pundit::Resource

  attributes :created_at, :updated_at
  
  # Add common helper for translated attributes
  def self.translatable_attribute(attr_name)
    attribute attr_name do
      @model.send(attr_name)
    end
  end
  
  # Add common helper for attachment URLs
  def attachment_url(attachment_name)
    attachment = @model.send(attachment_name)
    return nil unless attachment.attached?
    
    Rails.application.routes.url_helpers.url_for(attachment)
  rescue ActiveStorage::FileNotFoundError
    nil
  end
end
```

**File:** `app/future_controllers/better_together/api_controller.rb`

**Changes:**
```ruby
class ApiController < ::JSONAPI::ResourceController
  include Pundit::Authorization
  include Pundit::ResourceController

  protect_from_forgery with: :exception, unless: -> { request.format.json? }
  
  # Add authentication by default
  before_action :authenticate_user!
  
  # Ensure authorization is called
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index
  
  # Handle Pundit errors
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  
  private
  
  def user_not_authorized
    render jsonapi_errors: [{ 
      title: 'Not Authorized',
      detail: 'You are not authorized to perform this action',
      status: '403'
    }], status: :forbidden
  end
  
  def context
    { user: current_user, agent: current_user&.person }
  end
end
```

#### 1.2 Create Missing Resources

**Priority Order:**

1. **SessionResource** (authentication responses)
2. **Update UserResource** (security fixes)
3. **Update CommunityResource** (add missing attributes)
4. **Update PersonResource** (add missing attributes)
5. **Rename/Fix PersonCommunityMembershipResource**
6. **Update RoleResource** (minor fixes)

### Phase 2: File Migration

#### 2.1 Directory Structure Mapping

**From `future_controllers/` to `controllers/`:**

```
app/future_controllers/better_together/
├── api_controller.rb → app/controllers/better_together/api_controller.rb
└── bt/
    └── api/
        ├── auth/
        │   └── sessions_controller.rb → app/controllers/better_together/bt/api/auth/sessions_controller.rb
        ├── confirmations_controller.rb → app/controllers/better_together/bt/api/confirmations_controller.rb
        ├── passwords_controller.rb → app/controllers/better_together/bt/api/passwords_controller.rb
        ├── registrations_controller.rb → app/controllers/better_together/bt/api/registrations_controller.rb
        ├── sessions_controller.rb → app/controllers/better_together/bt/api/sessions_controller.rb
        └── v1/
            ├── communities_controller.rb → app/controllers/better_together/bt/api/v1/communities_controller.rb
            ├── community_memberships_controller.rb → app/controllers/better_together/bt/api/v1/community_memberships_controller.rb
            ├── people_controller.rb → app/controllers/better_together/bt/api/v1/people_controller.rb
            └── roles_controller.rb → app/controllers/better_together/bt/api/v1/roles_controller.rb
```

**From `future_spec/` to `spec/`:**

```
future_spec/
├── concerns/
│   └── better_together/ → spec/concerns/better_together/
├── factories/
│   └── better_together/ → spec/factories/better_together/
├── models/
│   └── better_together/ → spec/models/better_together/
└── requests/
    └── better_together/
        └── api/ → spec/requests/better_together/api/
```

#### 2.2 Migration Script

**File:** `scripts/migrate_api_files.sh`

```bash
#!/bin/bash
set -e

echo "Starting API file migration..."

# Create target directories
mkdir -p app/controllers/better_together/bt/api/auth
mkdir -p app/controllers/better_together/bt/api/v1
mkdir -p spec/requests/better_together/api/auth
mkdir -p spec/requests/better_together/api/v1

# Move controllers
echo "Moving controllers..."
mv app/future_controllers/better_together/api_controller.rb \
   app/controllers/better_together/

mv app/future_controllers/better_together/bt/api/auth/sessions_controller.rb \
   app/controllers/better_together/bt/api/auth/

mv app/future_controllers/better_together/bt/api/confirmations_controller.rb \
   app/controllers/better_together/bt/api/

mv app/future_controllers/better_together/bt/api/passwords_controller.rb \
   app/controllers/better_together/bt/api/

mv app/future_controllers/better_together/bt/api/registrations_controller.rb \
   app/controllers/better_together/bt/api/

mv app/future_controllers/better_together/bt/api/sessions_controller.rb \
   app/controllers/better_together/bt/api/

mv app/future_controllers/better_together/bt/api/v1/*.rb \
   app/controllers/better_together/bt/api/v1/

# Move specs
echo "Moving specs..."
cp -r future_spec/requests/better_together/api/* \
      spec/requests/better_together/api/

# Move factories (if any new ones)
if [ -d "future_spec/factories/better_together" ]; then
  cp -r future_spec/factories/better_together/* \
        spec/factories/better_together/
fi

# Move model specs (if any)
if [ -d "future_spec/models/better_together" ]; then
  cp -r future_spec/models/better_together/* \
        spec/models/better_together/
fi

# Move concern specs (if any)
if [ -d "future_spec/concerns/better_together" ]; then
  cp -r future_spec/concerns/better_together/* \
        spec/concerns/better_together/
fi

echo "Migration complete!"
echo "Please review changes and run tests."
```

### Phase 3: Route Activation

#### 3.1 Uncomment and Update Routes

**File:** `config/routes/api_routes.rb`

**Before:**
```ruby
# TODO: Re-enable the API routes when the API is in full use...
# namespace :bt do
#   namespace :api, defaults: { format: :json } do
#     ...
#   end
# end
```

**After:**
```ruby
namespace :bt do
  namespace :api, defaults: { format: :json } do
    # Authentication routes
    devise_for :users,
      class_name: BetterTogether.user_class.to_s,
      skip: [:unlocks, :omniauth_callbacks],
      path: 'auth',
      path_names: {
        sign_in: 'sign-in',
        sign_out: 'sign-out',
        registration: 'sign-up'
      },
      controllers: {
        sessions: 'better_together/bt/api/auth/sessions',
        registrations: 'better_together/bt/api/registrations',
        passwords: 'better_together/bt/api/passwords',
        confirmations: 'better_together/bt/api/confirmations'
      }

    namespace :v1 do
      # People
      get 'people/me', to: 'people#me'
      jsonapi_resources :people do
        jsonapi_relationships
      end
      
      # Communities
      jsonapi_resources :communities do
        jsonapi_relationships
      end

      # Community Memberships (PersonCommunityMemberships)
      jsonapi_resources :person_community_memberships do
        jsonapi_relationships
      end

      # Roles
      jsonapi_resources :roles do
        jsonapi_relationships
      end
    end
  end
end
```

### Phase 4: Testing

#### 4.1 Test Execution Plan

```bash
# 1. Run authentication specs
bin/dc-run bundle exec prspec spec/requests/better_together/api/auth/

# 2. Run resource specs
bin/dc-run bundle exec prspec spec/requests/better_together/api/v1/

# 3. Run security scans
bin/dc-run bundle exec brakeman --quiet --no-pager

# 4. Run full test suite
bin/dc-run bin/ci
```

#### 4.2 Required Test Coverage

**Authentication Tests:**
- [ ] User registration with person creation
- [ ] JWT token returned on login
- [ ] Token refresh mechanism
- [ ] Password reset flow
- [ ] Email confirmation flow
- [ ] Invalid credentials handling
- [ ] Rate limiting (if implemented)

**Resource Tests:**
- [ ] Community CRUD with authorization
- [ ] Person CRUD with privacy filtering
- [ ] Role index/show (no create/update/delete)
- [ ] PersonCommunityMembership CRUD with notifications
- [ ] Scope filtering by user permissions
- [ ] Pagination and meta data
- [ ] Relationship loading (includes)
- [ ] Filter handling

**Security Tests:**
- [ ] Unauthorized access returns 403
- [ ] Unauthenticated access returns 401
- [ ] Privacy filtering prevents data leaks
- [ ] Protected resources can't be deleted
- [ ] Password fields never returned
- [ ] CSRF protection for non-JSON requests

---

## 7. Documentation Requirements

### 7.1 API Documentation Structure

**Location:** `docs/developers/api/`

```
docs/developers/api/
├── README.md (Overview)
├── authentication.md
├── resources/
│   ├── communities.md
│   ├── people.md
│   ├── roles.md
│   ├── person_community_memberships.md
│   └── users.md
├── examples/
│   ├── authentication_flow.md
│   ├── creating_community.md
│   ├── managing_memberships.md
│   └── user_profile.md
└── errors.md
```

### 7.2 Required Documentation

#### Authentication Documentation
**File:** `docs/developers/api/authentication.md`

**Contents:**
- JWT token structure
- Token refresh mechanism
- Login/logout flows
- Registration with person creation
- Password reset
- Email confirmation
- Rate limiting (if implemented)
- Example requests/responses

#### Resource Documentation
**Template for each resource:**

```markdown
# [Resource Name] API

## Overview
Brief description of the resource and its purpose.

## Endpoints

### List [Resources]
`GET /bt/api/v1/[resources]`

**Authentication:** Required/Optional
**Authorization:** [Policy rules]

**Query Parameters:**
- `filter[attribute]` - Description
- `page[number]` - Page number
- `page[size]` - Page size
- `include` - Relationships to include

**Example Request:**
```http
GET /bt/api/v1/communities?filter[privacy]=public&include=creator
Authorization: Bearer <token>
```

**Example Response:**
```json
{
  "data": [
    {
      "id": "uuid",
      "type": "communities",
      "attributes": { ... },
      "relationships": { ... }
    }
  ],
  "included": [ ... ],
  "meta": { ... },
  "links": { ... }
}
```

### Show [Resource]
...

### Create [Resource]
...

### Update [Resource]
...

### Delete [Resource]
...

## Attributes

| Attribute | Type | Description | Readable | Writable |
|-----------|------|-------------|----------|----------|
| ... | ... | ... | ✓ / ✗ | ✓ / ✗ |

## Relationships

| Relationship | Type | Description |
|--------------|------|-------------|
| ... | has_one / has_many | ... |

## Filters

| Filter | Type | Description |
|--------|------|-------------|
| ... | ... | ... |

## Authorization

| Action | Required Permission | Additional Rules |
|--------|-------------------|------------------|
| ... | ... | ... |

## Examples

### [Common Use Case]
Detailed example with request/response
```

### 7.3 OpenAPI/Swagger Documentation

**Recommendation:** Generate OpenAPI 3.0 spec from RSpec integration tests

**Tool:** rswag gem

**Benefits:**
- Interactive API documentation
- Automatic API client generation
- Request/response validation
- Keeps docs in sync with tests

**Implementation:**
1. Add `rswag` gem
2. Create Swagger specs in `spec/requests/better_together/api/`
3. Generate swagger.json
4. Mount Swagger UI at `/api-docs`

---

## 8. Testing Strategy

### 8.1 Test Coverage Goals

| Component | Current Coverage | Target Coverage |
|-----------|-----------------|-----------------|
| ApiController | 0% | 100% |
| ApiResource | 0% | 100% |
| Authentication Controllers | 0% | 95% |
| V1 Controllers | 0% | 95% |
| Resources | Varies | 95% |
| Link Builder | 27.6% | 90% |
| Policies (API context) | Partial | 100% |

### 8.2 Test Types Required

#### Unit Tests (RSpec)
- **Resources:** Attribute mapping, relationships, filters
- **Policies:** Authorization rules in API context
- **Link Builder:** URL generation, engine handling

#### Integration Tests (Request Specs)
- **Authentication flows:** Login, logout, registration, password reset
- **CRUD operations:** Create, read, update, delete for each resource
- **Authorization:** Proper 401/403 responses
- **Scope filtering:** Privacy and permission-based filtering
- **Pagination:** Page metadata, links
- **Relationships:** Include parameter, relationship endpoints
- **Filters:** Query parameter handling

#### Feature Tests (where applicable)
- **End-to-end workflows:** Complete user journeys
- **Error handling:** Proper error responses
- **Edge cases:** Boundary conditions, race conditions

### 8.3 Test Data Strategy

**FactoryBot Factories Required:**
- [x] User
- [x] Person  
- [x] Community
- [x] PersonCommunityMembership
- [x] Role
- [ ] CommunityInvitation
- [ ] PlatformInvitation

**Test Helpers:**
- [x] `configure_host_platform`
- [x] `login(email, password)` (DeviseSessionHelpers)
- [ ] `api_headers(user)` - Returns JWT auth headers
- [ ] `jsonapi_response` - Parses JSONAPI response
- [ ] `expect_jsonapi_error(status, title)` - Error assertions

### 8.4 Continuous Integration

**GitHub Actions Workflow:**

```yaml
name: API Tests

on: [push, pull_request]

jobs:
  api_tests:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgis/postgis:14-3.2
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      
      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      
      - name: Run API specs
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost/test
          REDIS_URL: redis://localhost:6379/0
        run: |
          bin/dc-run bundle exec prspec spec/requests/better_together/api/
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

---

## 9. Security Considerations

### 9.1 Critical Security Issues (Must Fix Before Production)

| Issue | Severity | Impact | Fix Priority |
|-------|----------|--------|--------------|
| Password fields in UserResource | CRITICAL | Credentials exposure | IMMEDIATE |
| Raw user object in auth response | CRITICAL | Data leak | IMMEDIATE |
| No JWT token in auth response | HIGH | Broken authentication | HIGH |
| Missing authorization calls | HIGH | Unauthorized access | HIGH |
| No scope filtering | HIGH | Privacy violations | HIGH |
| No rate limiting | MEDIUM | Brute force attacks | MEDIUM |
| Incomplete person attributes in registration | MEDIUM | Missing required data | MEDIUM |

### 9.2 Security Checklist

#### Authentication & Authorization
- [ ] JWT tokens properly generated and returned
- [ ] Token refresh mechanism implemented
- [ ] Token expiration configured
- [ ] Token revocation (denylist) functional
- [ ] `authenticate_user!` on all protected endpoints
- [ ] `authorize` called for all policy-protected actions
- [ ] `policy_scope` used for index actions
- [ ] CSRF protection enabled for non-JSON requests

#### Data Protection
- [ ] Password fields NEVER returned in responses
- [ ] Privacy attribute respected in scopes
- [ ] Personal data filtered by authorization
- [ ] Protected resources can't be deleted via API
- [ ] Blocked users filtered from results
- [ ] Email addresses only visible to authorized users

#### Input Validation
- [ ] Strong parameters for all resources
- [ ] Nested attributes properly permitted
- [ ] File upload size limits enforced
- [ ] Content type validation for attachments
- [ ] SQL injection prevented (parameterized queries)
- [ ] XSS prevention (Rails auto-escaping)

#### Rate Limiting
- [ ] Authentication endpoints rate limited
- [ ] Password reset rate limited
- [ ] Registration rate limited
- [ ] Per-user API rate limits (optional)

#### Monitoring & Logging
- [ ] Failed authentication attempts logged
- [ ] Authorization failures logged
- [ ] Suspicious activity alerts configured
- [ ] API access logs enabled
- [ ] Error tracking (Sentry/Honeybadger)

### 9.3 Security Testing Requirements

**Brakeman Checks:**
```bash
bin/dc-run bundle exec brakeman --quiet --no-pager \
  -c UnsafeReflection,SQL,CrossSiteScripting,MassAssignment
```

**Manual Security Tests:**
- [ ] Attempt to access resources without authentication → 401
- [ ] Attempt to access forbidden resources → 403
- [ ] Attempt to modify other users' data → 403
- [ ] Attempt SQL injection in filters
- [ ] Attempt XSS in text fields
- [ ] Attempt to bypass privacy filters
- [ ] Attempt to delete protected resources
- [ ] Attempt to escalate privileges

---

## 10. Next Steps

### 10.1 Immediate Actions (Week 1)

**Priority 1: Security Fixes**
1. ✅ Update UserResource - remove password fields
2. ✅ Update RegistrationResource - make passwords write-only
3. ✅ Fix SessionsController - return proper JWT response
4. ✅ Add authorization calls to all controllers
5. ✅ Implement policy scopes in controllers

**Priority 2: Resource Updates**
1. ✅ Update CommunityResource - add missing attributes
2. ✅ Update PersonResource - add missing attributes
3. ✅ Rename/Fix CommunityMembershipResource → PersonCommunityMembershipResource
4. ✅ Update RoleResource - minor fixes
5. ✅ Create SessionResource for auth responses

**Priority 3: Base Class Improvements**
1. ✅ Update ApiController with auth/authorization defaults
2. ✅ Update ApiResource with translation helpers
3. ✅ Add attachment URL helpers to ApiResource

### 10.2 Short-term Actions (Weeks 2-3)

**Testing**
1. ⏳ Write request specs for all authentication flows
2. ⏳ Write request specs for all CRUD operations
3. ⏳ Write authorization tests for all endpoints
4. ⏳ Write scope filtering tests
5. ⏳ Achieve 95%+ test coverage

**Migration**
1. ⏳ Run migration script to move files
2. ⏳ Uncomment and update routes
3. ⏳ Fix any path/namespace issues
4. ⏳ Run full test suite
5. ⏳ Fix any failing tests

**Documentation**
1. ⏳ Write authentication documentation
2. ⏳ Write resource documentation for each endpoint
3. ⏳ Create example requests/responses
4. ⏳ Document error responses
5. ⏳ Consider OpenAPI/Swagger spec generation

### 10.3 Medium-term Actions (Weeks 4-6)

**Enhancements**
1. ⏳ Implement rate limiting (rack-attack)
2. ⏳ Add API versioning support (v2, v3, etc.)
3. ⏳ Implement API key authentication (optional)
4. ⏳ Add GraphQL support (optional, future consideration)
5. ⏳ Performance optimization (caching, N+1 prevention)

**Monitoring**
1. ⏳ Set up error tracking for API
2. ⏳ Configure API access logging
3. ⏳ Set up performance monitoring (APM)
4. ⏳ Create API usage dashboards
5. ⏳ Configure alerting for API issues

**Client SDKs** (Optional)
1. ⏳ Generate JavaScript/TypeScript SDK
2. ⏳ Generate Ruby client gem
3. ⏳ Create example client applications
4. ⏳ Document SDK usage

### 10.4 Long-term Actions (Future)

**API Evolution**
1. ⏳ Implement webhook support
2. ⏳ Add real-time capabilities (Action Cable API)
3. ⏳ Implement bulk operations
4. ⏳ Add export/import endpoints
5. ⏳ Consider public API for third-party integrations

**Performance**
1. ⏳ Implement response caching (ETags, Last-Modified)
2. ⏳ Optimize N+1 queries with includes
3. ⏳ Add database read replicas for API queries
4. ⏳ Implement CDN for API responses (optional)
5. ⏳ Consider API gateway (Kong, Tyk) for scaling

---

## Appendix A: File Checklist

### Controllers to Migrate

- [x] `app/future_controllers/better_together/api_controller.rb`
- [x] `app/future_controllers/better_together/bt/api/auth/sessions_controller.rb`
- [x] `app/future_controllers/better_together/bt/api/confirmations_controller.rb`
- [x] `app/future_controllers/better_together/bt/api/passwords_controller.rb`
- [x] `app/future_controllers/better_together/bt/api/registrations_controller.rb`
- [x] `app/future_controllers/better_together/bt/api/sessions_controller.rb`
- [x] `app/future_controllers/better_together/bt/api/v1/communities_controller.rb`
- [x] `app/future_controllers/better_together/bt/api/v1/community_memberships_controller.rb`
- [x] `app/future_controllers/better_together/bt/api/v1/people_controller.rb`
- [x] `app/future_controllers/better_together/bt/api/v1/roles_controller.rb`

### Resources to Update/Create

- [x] `app/resources/better_together/api_resource.rb` (update)
- [x] `app/resources/better_together/bt/api/v1/community_resource.rb` (update)
- [x] `app/resources/better_together/bt/api/v1/person_resource.rb` (update)
- [x] `app/resources/better_together/bt/api/v1/role_resource.rb` (update)
- [x] `app/resources/better_together/bt/api/v1/community_membership_resource.rb` (rename/fix)
- [x] `app/resources/better_together/bt/api/v1/user_resource.rb` (security fix)
- [x] `app/resources/better_together/bt/api/v1/registration_resource.rb` (security fix)
- [ ] `app/resources/better_together/bt/api/v1/session_resource.rb` (create)

### Specs to Migrate

- [ ] `future_spec/requests/better_together/api/auth/sessions_spec.rb`
- [ ] `future_spec/requests/better_together/api/auth/registrations_spec.rb`
- [ ] `future_spec/requests/better_together/api/auth/passwords_spec.rb`
- [ ] `future_spec/requests/better_together/api/auth/confirmations_spec.rb`
- [ ] `future_spec/requests/better_together/api/v1/communities_spec.rb`
- [ ] `future_spec/requests/better_together/api/v1/people_spec.rb`
- [ ] `future_spec/requests/better_together/api/v1/community_membership_spec.rb`
- [ ] `future_spec/requests/better_together/api/v1/roles_spec.rb`

### Documentation to Create

- [ ] `docs/developers/api/README.md`
- [ ] `docs/developers/api/authentication.md`
- [ ] `docs/developers/api/resources/communities.md`
- [ ] `docs/developers/api/resources/people.md`
- [ ] `docs/developers/api/resources/roles.md`
- [ ] `docs/developers/api/resources/person_community_memberships.md`
- [ ] `docs/developers/api/resources/users.md`
- [ ] `docs/developers/api/examples/authentication_flow.md`
- [ ] `docs/developers/api/errors.md`

---

## Appendix B: Example Implementations

### B.1 Updated SessionsController

```ruby
# app/controllers/better_together/bt/api/auth/sessions_controller.rb
module BetterTogether
  module Bt
    module Api
      module Auth
        class SessionsController < Devise::SessionsController
          respond_to :json

          protected

          def respond_with(resource, _opts = {})
            token = request.env['warden-jwt_auth.token']
            
            render json: {
              data: {
                type: 'sessions',
                attributes: {
                  email: resource.email,
                  token: token
                },
                relationships: {
                  person: {
                    data: {
                      type: 'people',
                      id: resource.person.id
                    }
                  }
                }
              },
              included: [
                {
                  type: 'people',
                  id: resource.person.id,
                  attributes: {
                    name: resource.person.name,
                    identifier: resource.person.identifier,
                    # ... other safe person attributes
                  }
                }
              ]
            }
          end

          def respond_to_on_destroy
            render json: {
              message: 'Logged out successfully'
            }, status: :ok
          end
        end
      end
    end
  end
end
```

### B.2 Updated CommunitiesController

```ruby
# app/controllers/better_together/bt/api/v1/communities_controller.rb
module BetterTogether
  module Bt
    module Api
      module V1
        class CommunitiesController < BetterTogether::Api::ApplicationController
          before_action :authenticate_user!, except: %i[index show]
          
          def index
            @communities = policy_scope(Community)
            render jsonapi: @communities
          end
          
          def show
            @community = Community.find(params[:id])
            authorize @community
            render jsonapi: @community
          end
          
          def create
            @community = Community.new(resource_params)
            authorize @community
            
            if @community.save
              render jsonapi: @community, status: :created
            else
              render jsonapi_errors: @community.errors, status: :unprocessable_entity
            end
          end
          
          def update
            @community = Community.find(params[:id])
            authorize @community
            
            if @community.update(resource_params)
              render jsonapi: @community
            else
              render jsonapi_errors: @community.errors, status: :unprocessable_entity
            end
          end
          
          def destroy
            @community = Community.find(params[:id])
            authorize @community
            
            @community.destroy
            head :no_content
          end
          
          private
          
          def resource_params
            params.require(:data)
                  .require(:attributes)
                  .permit(Community.permitted_attributes)
          end
        end
      end
    end
  end
end
```

### B.3 Updated CommunityResource

```ruby
# app/resources/better_together/bt/api/v1/community_resource.rb
module BetterTogether
  module Bt
    module Api
      module V1
        class CommunityResource < ::BetterTogether::ApiResource
          model_name '::BetterTogether::Community'

          # Translated attributes
          attributes :name, :description
          
          # Standard attributes
          attributes :slug, :identifier, :privacy, :protected, :host
          
          # Virtual attributes for attachments
          attribute :profile_image_url
          attribute :cover_image_url
          attribute :logo_url
          
          # Relationships
          has_one :creator, class_name: 'Person'
          has_many :members, class_name: 'Person'
          has_many :person_community_memberships
          
          # Filters
          filter :privacy
          filter :protected
          filter :creator_id
          
          # Custom attribute methods
          def profile_image_url
            attachment_url(:profile_image)
          end
          
          def cover_image_url
            attachment_url(:cover_image)
          end
          
          def logo_url
            attachment_url(:logo)
          end
          
          # Fetchable fields (customize what's available to query)
          def self.fetchable_fields(context)
            super - [:protected] # Don't allow filtering by protected unless admin
          end
          
          # Creatable and updatable fields
          def self.creatable_fields(context)
            super - [:slug, :protected, :host] # These are system-managed
          end
          
          def self.updatable_fields(context)
            creatable_fields(context)
          end
        end
      end
    end
  end
end
```

---

## Appendix C: Security Testing Checklist

### Authentication Tests
- [ ] Valid credentials return 200 and JWT token
- [ ] Invalid credentials return 401
- [ ] Missing credentials return 401
- [ ] Expired token returns 401
- [ ] Revoked token returns 401
- [ ] Registration creates user and person
- [ ] Registration requires email confirmation (if enabled)
- [ ] Password reset sends email
- [ ] Password reset with valid token works
- [ ] Password reset with invalid token fails

### Authorization Tests
- [ ] Unauthenticated user cannot create community
- [ ] Authenticated user without permission cannot create community
- [ ] Authenticated user with permission can create community
- [ ] User can view own person record
- [ ] User cannot view private person records
- [ ] User can view community members if member
- [ ] User cannot view community members if not member
- [ ] User cannot delete protected community
- [ ] User cannot delete other user's community

### Data Protection Tests
- [ ] Password never returned in any response
- [ ] Private person records not in index for non-members
- [ ] Blocked users filtered from results
- [ ] Email addresses hidden from unauthorized users
- [ ] Attachment URLs require authentication (if configured)

### Input Validation Tests
- [ ] Invalid email format rejected
- [ ] Weak password rejected (zxcvbn)
- [ ] Required fields enforced
- [ ] Invalid attribute values rejected
- [ ] Invalid relationships rejected
- [ ] File upload size limits enforced
- [ ] Invalid content types rejected

---

## Appendix D: Performance Optimization Checklist

### N+1 Query Prevention
- [ ] All index actions use `includes` for relationships
- [ ] Scope methods use `includes` where needed
- [ ] Attachment URLs don't cause N+1 queries

### Caching
- [ ] ETags enabled for GET requests
- [ ] Last-Modified headers set
- [ ] Cache-Control headers configured
- [ ] Fragment caching for complex responses (optional)

### Database Optimization
- [ ] Indexes on foreign keys
- [ ] Indexes on commonly filtered columns
- [ ] Composite indexes for multi-column filters
- [ ] Database query monitoring enabled

### Response Optimization
- [ ] Sparse fieldsets supported
- [ ] Pagination limits enforced
- [ ] Large collections paginated by default
- [ ] Relationship loading optimized

---

## Appendix E: Migration Timeline

### Week 1: Preparation & Security Fixes
**Days 1-2:** Security fixes
- Update UserResource
- Update RegistrationResource
- Fix SessionsController
- Add authorization to controllers

**Days 3-4:** Resource updates
- Update CommunityResource
- Update PersonResource
- Fix PersonCommunityMembershipResource
- Update RoleResource

**Day 5:** Base class improvements
- Update ApiController
- Update ApiResource
- Test all changes

### Week 2: Testing & Migration
**Days 1-3:** Write tests
- Authentication specs
- CRUD specs
- Authorization specs
- Scope filtering specs

**Days 4-5:** File migration
- Run migration script
- Fix path issues
- Run full test suite
- Fix failing tests

### Week 3: Documentation & Deployment
**Days 1-2:** Documentation
- Authentication docs
- Resource docs
- Example docs

**Days 3-4:** Final testing & security review
- Security audit
- Performance testing
- User acceptance testing

**Day 5:** Production deployment
- Uncomment routes in production
- Monitor error logs
- Verify functionality
- Address any issues

---

## Conclusion

The JSONAPI implementation is functionally ready but requires critical security fixes, resource updates, policy integration, and comprehensive testing before production use. The migration from `future_*` directories is straightforward, but the code quality and security improvements are essential.

**Key Takeaways:**

1. **Security First:** Password exposure and missing authorization must be fixed immediately
2. **Model Alignment:** Resources need updates to match current model structure
3. **Policy Integration:** Explicit authorization calls and scope filtering required
4. **Testing:** Comprehensive test coverage needed before production
5. **Documentation:** API documentation critical for frontend teams and third-party integrators

**Estimated Timeline:** 3 weeks to production-ready state with proper testing and documentation.

**Risk Level:** Medium → Low (after security fixes)

**Recommendation:** Proceed with Phase 1 (security fixes) immediately, followed by systematic migration and testing.
