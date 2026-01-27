# JSONAPI Implementation Reassessment - January 27, 2026

**Status:** Files Migrated, Namespaces Corrected ✅  
**Priority:** Address Remaining Issues (Security, Model Alignment)

## Executive Summary

The user has successfully migrated JSONAPI files from `future_*` directories to production locations and corrected namespace inconsistencies. This reassessment evaluates the current state and identifies remaining work needed before API activation.

---

## ✅ What's Been Fixed

### 1. File Migration Complete
**All files moved from `future_*` to production directories:**

- ✅ `future_controllers/` → `app/controllers/better_together/api/`
- ✅ `future_spec/` → `spec/requests/better_together/api/`
- ✅ All controller and resource files now in correct locations

### 2. Namespace Corrections Applied

#### Controllers
**Before:** Mixed `BetterTogether::Bt::Api` namespace  
**After:** Consistent `BetterTogether::Api` namespace ✅

```ruby
# ✅ CORRECT - All controllers now use this pattern
module BetterTogether
  module Api
    module V1
      class CommunitiesController < ApplicationController
        # ...
      end
    end
  end
end
```

#### Resources
**Before:** Mixed `BetterTogether::Bt::Api::V1` namespace  
**After:** Consistent `BetterTogether::Api::V1` namespace ✅

```ruby
# ✅ CORRECT - All resources now use this pattern
module BetterTogether
  module Api
    module V1
      class CommunityResource < ::BetterTogether::Api::ApplicationResource
        # ...
      end
    end
  end
end
```

### 3. Class Hierarchy Improvements

#### Controllers
**Auth controllers now inherit from proper Devise base classes:**

```ruby
# ✅ IMPROVED - Better inheritance hierarchy
module BetterTogether::Api::Auth
  class SessionsController < BetterTogether::Users::SessionsController
  class RegistrationsController < BetterTogether::Users::RegistrationsController
  class PasswordsController < BetterTogether::Users::PasswordsController
  class ConfirmationsController < BetterTogether::Users::ConfirmationsController
end
```

**V1 controllers now reference local ApplicationController:**

```ruby
# ✅ IMPROVED - Shortened reference (no longer ApiController)
module BetterTogether::Api::V1
  class CommunitiesController < ApplicationController
  class PeopleController < ApplicationController
  class RolesController < ApplicationController
  class CommunityMembershipsController < ApplicationController
end
```

#### Resources
**All resources now inherit from ApplicationResource:**

```ruby
# ✅ IMPROVED - Consistent base class
module BetterTogether::Api::V1
  class CommunityResource < ::BetterTogether::Api::ApplicationResource
  class PersonResource < ::BetterTogether::Api::ApplicationResource
  class RoleResource < ::BetterTogether::Api::ApplicationResource
  class UserResource < ::BetterTogether::Api::ApplicationResource
  class CommunityMembershipResource < ::BetterTogether::Api::ApplicationResource
  class RegistrationResource < ::BetterTogether::Api::ApplicationResource
end
```

### 4. Base Classes Renamed

**ApiController → ApplicationController:**
- `app/controllers/better_together/api/application_controller.rb`
- Now follows Rails convention

**ApiResource → ApplicationResource:**
- `app/resources/better_together/api/application_resource.rb`
- Now follows Rails convention

---

## ⚠️ Issues Requiring Attention

### 1. Outdated require_dependency Statements

**Location:** All V1 controllers have obsolete requires  
**Impact:** May cause load errors or confusion

**Files affected:**
- `app/controllers/better_together/api/v1/communities_controller.rb`
- `app/controllers/better_together/api/v1/people_controller.rb`
- `app/controllers/better_together/api/v1/roles_controller.rb`
- `app/controllers/better_together/api/v1/community_memberships_controller.rb`

**Current (incorrect):**
```ruby
require_dependency 'better_together/api_controller'
```

**Should be:**
```ruby
# Remove this line - not needed with proper namespacing
# Controllers now inherit from ApplicationController which is in the same namespace
```

### 2. Outdated require_dependency in Resources

**Location:** All V1 resources have obsolete requires  
**Impact:** May cause load errors or confusion

**Files affected:**
- All 6 resource files in `app/resources/better_together/api/v1/`

**Current (incorrect):**
```ruby
require_dependency 'better_together/api_resource'
```

**Should be:**
```ruby
# Remove this line - not needed with proper namespacing
# Resources now inherit from ApplicationResource which is in the same namespace
```

### 3. Controller Reference to Non-Existent Class

**Location:** V1 controllers reference `ApiController`  
**Issue:** Class was renamed to `ApplicationController`

**Current:**
```ruby
class CommunitiesController < BetterTogether::Api::ApplicationController  # ❌ ApiController doesn't exist
```

**Should be:**
```ruby
class CommunitiesController < ApplicationController  # ✅ Correct
```

**BUT** this is already correct in the files! Just noting for clarity.

---

## 🔴 Critical Security Issues (From Original Assessment - Still Valid)

### 1. Password Exposure in UserResource
**File:** `app/resources/better_together/api/v1/user_resource.rb`

```ruby
# ❌ CRITICAL SECURITY ISSUE - Passwords in API response
attributes :email, :password, :password_confirmation
```

**Fix Required:**
```ruby
# ✅ SECURE - Remove password fields entirely
attributes :email

attribute :confirmed  # Virtual boolean

def confirmed
  @model.confirmed_at.present?
end

# Add relationship
has_one :person, class_name: 'Person'
```

### 2. Raw User Object Response in Auth
**File:** `app/controllers/better_together/api/auth/sessions_controller.rb`

```ruby
# ❌ SECURITY RISK - Exposes all user attributes
def respond_with(resource, _opts = {})
  render json: resource
end
```

**Fix Required:**
```ruby
# ✅ SECURE - Return JWT token + safe user data
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
          data: { type: 'people', id: resource.person.id }
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
          privacy: resource.person.privacy
        }
      }
    ]
  }
end
```

### 3. Missing Authorization Calls
**All V1 controllers lack Pundit authorization**

**Current:**
```ruby
# ❌ NO AUTHORIZATION - Anyone authenticated can do anything
class CommunitiesController < ApplicationController
  before_action :authenticate_user!, except: %i[index]
end
```

**Fix Required:**
```ruby
# ✅ PROPER AUTHORIZATION
class CommunitiesController < ApplicationController
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

### 4. ApplicationController Missing Auth/Authz Defaults

**Current:**
```ruby
class ApplicationController < ::JSONAPI::ResourceController
  include Pundit::Authorization
  include Pundit::ResourceController

  protect_from_forgery with: :exception, unless: -> { request.format.json? }
end
```

**Should Add:**
```ruby
class ApplicationController < ::JSONAPI::ResourceController
  include Pundit::Authorization
  include Pundit::ResourceController

  protect_from_forgery with: :exception, unless: -> { request.format.json? }
  
  # Ensure authentication by default
  before_action :authenticate_user!
  
  # Ensure authorization is called
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index
  
  # Handle authorization failures
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

---

## 📊 Model Alignment Issues (From Original Assessment - Still Valid)

### CommunityResource - Missing Attributes

**Current:**
```ruby
attributes :name, :description, :slug, :creator_id
has_one :creator, class_name: 'Person'
```

**Missing Critical Attributes:**
- `identifier` (CRITICAL - required for references)
- `privacy` (CRITICAL - security/data protection)
- `protected` (HIGH - prevents deletion)
- `host` (HIGH - platform host flag)
- `profile_image_url` (MEDIUM - attachment)
- `cover_image_url` (MEDIUM - attachment)
- `logo_url` (MEDIUM - attachment)

**Missing Relationships:**
- `has_many :members, class_name: 'Person'`
- `has_many :person_community_memberships`
- `has_many :calendars`

### PersonResource - Missing Attributes

**Current:**
```ruby
attributes :name, :description, :slug
```

**Missing Critical Attributes:**
- `identifier` (CRITICAL - @handle)
- `privacy` (CRITICAL - security)
- `email` (HIGH - user context)
- `locale` (HIGH - i18n)
- `time_zone` (HIGH - timezone)
- `receive_messages_from_members` (MEDIUM)
- `notify_by_email` (MEDIUM)
- `show_conversation_details` (MEDIUM)
- `profile_image_url` (MEDIUM)
- `cover_image_url` (MEDIUM)

**Missing Relationships:**
- `has_one :user`
- `has_many :communities`
- `has_many :person_community_memberships`
- `has_many :conversations`
- `has_many :person_blocks`

### RoleResource - Minor Gaps

**Current:**
```ruby
attributes :name, :description, :sort_order, :reserved
```

**Issues:**
- Using `reserved` instead of `protected` (model uses `protected`)
- Missing `identifier`
- Missing `resource_type`
- Missing `position` (Positioned concern)

### CommunityMembershipResource - Wrong Model Name

**CRITICAL ISSUE:**
```ruby
model_name '::BetterTogether::CommunityMembership'
```

**Problem:** Model is actually `PersonCommunityMembership`, not `CommunityMembership`

**Fix Required:**
```ruby
# Either rename resource to PersonCommunityMembershipResource
# OR fix model_name:
model_name '::BetterTogether::PersonCommunityMembership'

# Also add missing attributes:
attribute :status  # enum: pending, active
```

---

## 🧪 Testing Status

### Request Specs Migrated ✅
All specs moved to proper location:
- `spec/requests/better_together/api/auth/`
- `spec/requests/better_together/api/v1/`

### Spec Content
**Current:** All spec files contain only `require 'swagger_helper'`

**Required:** Full request spec implementation with:
- Authentication tests
- CRUD operation tests
- Authorization tests
- Scope filtering tests
- Error handling tests
- Security tests

---

## 📝 Routes Status

**Current:** Routes are commented out in `config/routes/api_routes.rb`

**Ready to uncomment?** ⚠️ NO - Security issues must be fixed first

**When fixed, update routes to match new namespacing:**

```ruby
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
      sessions: 'better_together/api/auth/sessions',
      registrations: 'better_together/api/auth/registrations',
      passwords: 'better_together/api/auth/passwords',
      confirmations: 'better_together/api/auth/confirmations'
    }

  namespace :v1 do
    get 'people/me', to: 'people#me'
    
    jsonapi_resources :people do
      jsonapi_relationships
    end
    
    jsonapi_resources :communities do
      jsonapi_relationships
    end

    jsonapi_resources :person_community_memberships do
      jsonapi_relationships
    end

    jsonapi_resources :roles do
      jsonapi_relationships
    end
  end
end
```

---

## 🔧 Required Fixes - Priority Order

### Priority 1: Security (This Week)

1. **Fix UserResource** - Remove password fields
2. **Fix SessionsController** - Return JWT token properly
3. **Fix RegistrationsController** - Remove raw resource response
4. **Add authorization to all V1 controllers** - Call `authorize` and `policy_scope`
5. **Update ApplicationController** - Add auth/authz defaults

### Priority 2: Code Cleanup (This Week)

1. **Remove obsolete require_dependency statements** (all controllers and resources)
2. **Fix CommunityMembershipResource model name** → `PersonCommunityMembership`
3. **Add missing attributes to all resources** (see model alignment section)

### Priority 3: Testing (Next Week)

1. **Write authentication request specs**
2. **Write CRUD request specs**
3. **Write authorization specs**
4. **Write security specs**

### Priority 4: Documentation & Deployment (Week 3)

1. **Create API documentation**
2. **Uncomment routes**
3. **Deploy to staging for testing**
4. **Production deployment**

---

## 📋 Updated File Checklist

### Controllers ✅ Migrated, ⚠️ Need Updates

- [✅] `app/controllers/better_together/api/application_controller.rb` (needs auth defaults)
- [✅] `app/controllers/better_together/api/auth/sessions_controller.rb` (needs JWT response)
- [✅] `app/controllers/better_together/api/auth/registrations_controller.rb` (needs secure response)
- [✅] `app/controllers/better_together/api/auth/passwords_controller.rb`
- [✅] `app/controllers/better_together/api/auth/confirmations_controller.rb`
- [✅] `app/controllers/better_together/api/v1/communities_controller.rb` (needs authorization)
- [✅] `app/controllers/better_together/api/v1/people_controller.rb` (needs authorization)
- [✅] `app/controllers/better_together/api/v1/roles_controller.rb` (needs authorization)
- [✅] `app/controllers/better_together/api/v1/community_memberships_controller.rb` (needs authorization)

### Resources ✅ Migrated, ⚠️ Need Updates

- [✅] `app/resources/better_together/api/application_resource.rb` (needs helper methods)
- [⚠️] `app/resources/better_together/api/v1/community_resource.rb` (needs 10+ attributes)
- [⚠️] `app/resources/better_together/api/v1/person_resource.rb` (needs 12+ attributes)
- [⚠️] `app/resources/better_together/api/v1/role_resource.rb` (minor updates)
- [🔴] `app/resources/better_together/api/v1/user_resource.rb` (SECURITY - remove passwords)
- [⚠️] `app/resources/better_together/api/v1/registration_resource.rb` (SECURITY - remove passwords)
- [🔴] `app/resources/better_together/api/v1/community_membership_resource.rb` (wrong model name)

### Specs ✅ Migrated, ❌ Need Implementation

- [✅] `spec/requests/better_together/api/auth/sessions_spec.rb` (needs content)
- [✅] `spec/requests/better_together/api/auth/registrations_spec.rb` (needs content)
- [✅] `spec/requests/better_together/api/auth/passwords_spec.rb` (needs content)
- [✅] `spec/requests/better_together/api/auth/confirmations_spec.rb` (needs content)
- [✅] `spec/requests/better_together/api/v1/communities_spec.rb` (needs content)
- [✅] `spec/requests/better_together/api/v1/people_spec.rb` (needs content)
- [✅] `spec/requests/better_together/api/v1/roles_spec.rb` (needs content)
- [✅] `spec/requests/better_together/api/v1/community_membership_spec.rb` (needs content)

---

## 🎯 Immediate Next Steps

### Step 1: Clean Up Require Dependencies (5 minutes)

Remove obsolete `require_dependency` statements from all files:
- All V1 controllers (4 files)
- All V1 resources (6 files)

### Step 2: Fix Security Issues (2 hours)

1. Update UserResource - remove password fields
2. Update RegistrationResource - remove password fields  
3. Update SessionsController - return JWT token
4. Update ApplicationController - add auth/authz defaults
5. Run Brakeman security scan

### Step 3: Add Authorization to Controllers (3 hours)

1. Update CommunitiesController - add authorize calls
2. Update PeopleController - add authorize calls
3. Update RolesController - add authorize calls
4. Update CommunityMembershipsController - add authorize calls

### Step 4: Fix Model Alignment (4 hours)

1. Fix CommunityMembershipResource model name
2. Update CommunityResource with missing attributes
3. Update PersonResource with missing attributes
4. Update RoleResource minor fixes
5. Add attachment URL helpers to ApplicationResource

### Step 5: Write Tests (1-2 days)

1. Authentication request specs
2. CRUD request specs with authorization
3. Security test cases
4. Run full test suite

### Step 6: Documentation & Deployment (3-5 days)

1. API documentation
2. Enable routes
3. Staging deployment & testing
4. Production deployment

---

## 📈 Progress Summary

| Category | Status | Completion |
|----------|--------|------------|
| File Migration | ✅ Complete | 100% |
| Namespace Consistency | ✅ Complete | 100% |
| Class Hierarchy | ✅ Improved | 100% |
| Require Dependencies | ⚠️ Needs Cleanup | 0% |
| Security Fixes | 🔴 Critical Issues | 0% |
| Authorization | 🔴 Missing | 0% |
| Resource Attributes | ⚠️ Incomplete | 30% |
| Testing | ❌ Not Started | 0% |
| Documentation | ❌ Not Started | 0% |
| Routes | ⏸️ Commented Out | 0% |

**Overall Readiness:** 40% → Production requires 100%

---

## Conclusion

✅ **Great progress** on file organization and namespace consistency!

🔴 **Critical blockers** remain:
1. Security vulnerabilities (password exposure, missing authorization)
2. Incomplete resource definitions
3. No test coverage
4. Missing documentation

**Estimated time to production-ready:** 1-2 weeks with focused effort

**Recommendation:** Start with Priority 1 (Security) immediately, as these are critical vulnerabilities that must be fixed before any API activation.
