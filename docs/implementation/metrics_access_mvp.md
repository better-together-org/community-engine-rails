# Metrics Access MVP - Implementation Plan

**Date:** December 19, 2025  
**Status:** Ready for Implementation  
**Priority:** High  
**Estimated Effort:** 16-20 hours

## MVP Goal

Enable platform managers to grant read-only metrics access to specific users without giving them full platform management permissions.

**Out of Scope for MVP:**
- Time-based memberships (no expiration)
- Role request workflows  
- Section access UI (future extensibility)
- Auto-renewal workflows
- PaperTrail audit logging (add in v2)

## What We're Building

### Core Features
1. **Three granular metrics permissions:**
   - `view_metrics_dashboard` - View metrics section and list of reports
   - `create_metrics_reports` - Create/generate new reports (POST action)
   - `download_metrics_reports` - Download existing report files
2. New "Analytics Viewer" platform role with those permissions
3. Pundit policies for all metrics controllers
4. Updated routing constraints
5. Analytics navigation item (only visible to authorized users)
6. Simple UI for platform managers to assign the Analytics Viewer role

## Permission Semantics Clarification

- **`create_metrics_reports`**: Controls the POST `/reports` action which creates a new report record and synchronously generates its data
- **`download_metrics_reports`**: Controls the GET `/reports/:id/download` action which sends existing report files to users
- These are intentionally separate - you may want users who can create reports but only download their own, or restrict downloads to managers only

## Quick Start Checklist

- [ ] Step 1: Create 3 new permissions (2 hrs)
- [ ] Step 2: Create Analytics Viewer role (1 hr)
- [ ] Step 3: Create 4 Pundit policies (3 hrs)
- [ ] Step 4: Add authorization to controllers (2 hrs)
- [ ] Step 5: Update routing constraints (1 hr)
- [ ] Step 6: Add Analytics navigation (2 hrs)
- [ ] Step 7: Build role assignment UI (3 hrs)
- [ ] Step 8: Seed data & translations (2 hrs)
- [ ] Step 9: Fix HostDashboard security (1 hr)
- [ ] Step 10: Write tests (3-4 hrs)

**Total: 20 hours**

## Testing Checklist

- [ ] Analytics Viewer can access metrics dashboard
- [ ] Analytics Viewer can create new reports
- [ ] Analytics Viewer can download reports
- [ ] Regular users get 403 on metrics routes
- [ ] Analytics navigation shows/hides correctly
- [ ] Platform managers can grant access
- [ ] Platform managers can revoke access
- [ ] All RSpec tests passing
- [ ] Brakeman scan clean

## Implementation Steps

### Step 1: Add Granular Permissions (2 hours)

**File:** `app/builders/better_together/access_control_builder.rb`

Add three new permissions to the `platform_permissions` method:

```ruby
def platform_permissions
  [
    # ... existing permissions ...
    { identifier: 'view_metrics_dashboard', protected: true },
    { identifier: 'create_metrics_reports', protected: true },
    { identifier: 'download_metrics_reports', protected: true }
  ]
end
```

Remove or deprecate the unused `view_platform_analytics` permission.

### Step 2: Create Analytics Viewer Role (1 hour)

**File:** `app/builders/better_together/access_control_builder.rb`

Add new role to `platform_roles` method:

```ruby
def platform_roles
  [
    # ... existing roles ...
    {
      identifier: 'platform_analytics_viewer',
      resource_type: 'BetterTogether::Platform',
      reserved: true,
      permission_identifiers: [
        'view_metrics_dashboard',
        'create_metrics_reports', 
        'download_metrics_reports'
      ]
    }
  ]
end
```

Update `platform_manager` role to include new metrics permissions:

```ruby
{
  identifier: 'platform_manager',
  # ... existing config ...
  permission_identifiers: [
    # ... existing permissions ...
    'view_metrics_dashboard',
    'create_metrics_reports',
    'download_metrics_reports'
  ]
}
```

### Step 3: Create Pundit Policies (3 hours)

**File:** `app/policies/better_together/host_dashboard_policy.rb` (NEW)

```ruby
# frozen_string_literal: true

module BetterTogether
  class HostDashboardPolicy < ApplicationPolicy
    def show?
      user.permitted_to?(:manage_platform, record)
    end
  end
end
```

**File:** `app/policies/better_together/metrics/reports_policy.rb` (NEW)

```ruby
# frozen_string_literal: true

module BetterTogether
  module Metrics
    class ReportsPolicy < ApplicationPolicy
      def index?
        can_view_metrics?
      end

      def show?
        can_view_metrics?
      end

      def create?
        can_create_reports?
      end

      def download?
        can_download_reports?
      end

      private

      def can_view_metrics?
        user.permitted_to?(:view_metrics_dashboard, platform) ||
          user.permitted_to?(:manage_platform, platform)
      end

      def can_create_reports?
        user.permitted_to?(:create_metrics_reports, platform) ||
          user.permitted_to?(:manage_platform, platform)
      end

      def can_download_reports?
        user.permitted_to?(:download_metrics_reports, platform) ||
          user.permitted_to?(:manage_platform, platform)
      end

      def platform
        @platform ||= BetterTogether::Platform.find_by(host: true)
      end
    end
  end
end
```

**File:** `app/policies/better_together/metrics/page_view_reports_policy.rb` (NEW)

```ruby
# frozen_string_literal: true

module BetterTogether
  module Metrics
    class PageViewReportsPolicy < ApplicationPolicy
      def index?
        can_view_metrics?
      end

      def show?
        can_view_metrics?
      end

      def create?
        can_create_reports?
      end

      def destroy?
        can_create_reports?
      end

      private

      def can_view_metrics?
        user.permitted_to?(:view_metrics_dashboard, platform) ||
          user.permitted_to?(:manage_platform, platform)
      end

      def can_create_reports?
        user.permitted_to?(:create_metrics_reports, platform) ||
          user.permitted_to?(:manage_platform, platform)
      end

      def platform
        @platform ||= BetterTogether::Platform.find_by(host: true)
      end
    end
  end
end
```

**File:** `app/policies/better_together/metrics/link_click_reports_policy.rb` (NEW)

```ruby
# frozen_string_literal: true

module BetterTogether
  module Metrics
    class LinkClickReportsPolicy < ApplicationPolicy
      def index?
        can_view_metrics?
      end

      def show?
        can_view_metrics?
      end

      def create?
        can_create_reports?
      end

      def destroy?
        can_create_reports?
      end

      private

      def can_view_metrics?
        user.permitted_to?(:view_metrics_dashboard, platform) ||
          user.permitted_to?(:manage_platform, platform)
      end

      def can_create_reports?
        user.permitted_to?(:create_metrics_reports, platform) ||
          user.permitted_to?(:manage_platform, platform)
      end

      def platform
        @platform ||= BetterTogether::Platform.find_by(host: true)
      end
    end
  end
end
```

**File:** `app/policies/better_together/metrics/link_checker_reports_policy.rb` (NEW)

```ruby
# frozen_string_literal: true

module BetterTogether
  module Metrics
    class LinkCheckerReportsPolicy < ApplicationPolicy
      def index?
        can_view_metrics?
      end

      def show?
        can_view_metrics?
      end

      def create?
        can_create_reports?
      end

      def destroy?
        can_create_reports?
      end

      private

      def can_view_metrics?
        user.permitted_to?(:view_metrics_dashboard, platform) ||
          user.permitted_to?(:manage_platform, platform)
      end

      def can_create_reports?
        user.permitted_to?(:create_metrics_reports, platform) ||
          user.permitted_to?(:manage_platform, platform)
      end

      def platform
        @platform ||= BetterTogether::Platform.find_by(host: true)
      end
    end
  end
end
```

### Step 4: Add Controller Authorization (2 hours)

Update all metrics controllers to use Pundit:

**Files to modify:**
- `app/controllers/better_together/host_dashboard_controller.rb`
- `app/controllers/better_together/metrics/reports_controller.rb`
- `app/controllers/better_together/metrics/page_view_reports_controller.rb`
- `app/controllers/better_together/metrics/link_click_reports_controller.rb`
- `app/controllers/better_together/metrics/link_checker_reports_controller.rb`

**Pattern for HostDashboardController:**

```ruby
module BetterTogether
  class HostDashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_host_dashboard

    def show
      # existing implementation
    end

    private

    def authorize_host_dashboard
      authorize :host_dashboard
    end
  end
end
```

**Pattern for ReportsController:**

```ruby
module BetterTogether
  module Metrics
    class ReportsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_report, only: %i[show download]
      before_action -> { authorize [:metrics, :reports], :index? }, only: :index
      before_action -> { authorize [:metrics, @report] }, only: :show
      before_action -> { authorize [:metrics, :reports], :create? }, only: :create
      before_action -> { authorize [:metrics, @report], :download? }, only: :download

      # ... existing actions ...
    end
  end
end
```

### Step 5: Update Routing Constraints (1 hour)

**File:** `config/routes.rb` (lines 196-228)

Change from:

```ruby
authenticated ->(warden) { warden.user.permitted_to?(:manage_platform, BetterTogether::Platform.find_by(host: true)) } do
  # metrics routes
end
```

To:

```ruby
authenticated ->(warden) { 
  platform = BetterTogether::Platform.find_by(host: true)
  warden.user.permitted_to?(:view_metrics_dashboard, platform) || 
    warden.user.permitted_to?(:manage_platform, platform)
} do
  # metrics routes
end
```

### Step 6: Add Analytics Navigation (2 hours)

**File:** `app/builders/better_together/navigation_builder.rb`

Add navigation item in appropriate section:

```ruby
def platform_management_items
  [
    # ... existing items ...
    {
      identifier: 'analytics',
      url_method: :metrics_reports_path,
      icon: 'chart-line',
      permission_identifier: 'view_metrics_dashboard'
    }
  ]
end
```

**Verification:** Check view where navigation renders to ensure permission checking:

```erb
<% if current_user.permitted_to?(item[:permission_identifier], platform) %>
  <%= link_to ... %>
<% end %>
```

### Step 7: Role Assignment UI (3 hours)

**File:** `app/views/better_together/platforms/show.html.erb`

Add new section after community management, before the closing tags:

```erb
<!-- Analytics Access Section -->
<div class="card mt-4">
  <div class="card-header">
    <h3 class="card-title">
      <i class="fa fa-chart-line me-2"></i>
      <%= t('.analytics_access.title') %>
    </h3>
  </div>
  <div class="card-body">
    <% if policy(@platform).manage? %>
      <!-- Grant Access Form -->
      <div class="mb-4">
        <h4><%= t('.analytics_access.grant_access') %></h4>
        <%= form_with(
          url: platform_memberships_path(@platform),
          method: :post,
          data: { turbo_frame: 'analytics-viewers' }
        ) do |f| %>
          <div class="row g-3">
            <div class="col-md-8">
              <%= f.label :person_id, t('.analytics_access.select_person'), class: 'form-label' %>
              <%= f.select :person_id,
                options_for_select(
                  Person.where.not(
                    id: @platform.members_with_role('platform_analytics_viewer').pluck(:id)
                  ).pluck(:name, :id)
                ),
                { include_blank: t('.analytics_access.choose_person') },
                { class: 'form-select', data: { controller: 'slim-select' } }
              %>
            </div>
            <div class="col-md-4 d-flex align-items-end">
              <%= f.hidden_field :role_id, value: @platform.roles.find_by(identifier: 'platform_analytics_viewer')&.id %>
              <%= f.submit t('.analytics_access.grant_button'), class: 'btn btn-primary w-100' %>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Current Analytics Viewers -->
      <%= turbo_frame_tag 'analytics-viewers' do %>
        <h4><%= t('.analytics_access.current_viewers') %></h4>
        <% analytics_viewers = @platform.members_with_role('platform_analytics_viewer') %>
        <% if analytics_viewers.any? %>
          <div class="table-responsive">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th><%= t('.analytics_access.table.person') %></th>
                  <th><%= t('.analytics_access.table.granted_at') %></th>
                  <th class="text-end"><%= t('.analytics_access.table.actions') %></th>
                </tr>
              </thead>
              <tbody>
                <% analytics_viewers.each do |viewer| %>
                  <% membership = viewer.platform_memberships.find_by(platform: @platform) %>
                  <tr>
                    <td><%= link_to viewer.name, person_path(viewer) %></td>
                    <td><%= l(membership.created_at, format: :short) %></td>
                    <td class="text-end">
                      <%= button_to t('.analytics_access.revoke_button'),
                        platform_membership_path(@platform, membership),
                        method: :delete,
                        data: { 
                          turbo_frame: 'analytics-viewers',
                          turbo_confirm: t('.analytics_access.revoke_confirm', name: viewer.name)
                        },
                        class: 'btn btn-sm btn-outline-danger'
                      %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% else %>
          <p class="text-muted"><%= t('.analytics_access.no_viewers') %></p>
        <% end %>
      <% end %>
    <% else %>
      <p class="text-muted"><%= t('.analytics_access.no_permission') %></p>
    <% end %>
  </div>
</div>
```

**Required Helper Method** in `PlatformsHelper` or `Platform` model:

```ruby
def members_with_role(role_identifier)
  role = roles.find_by(identifier: role_identifier)
  return Person.none unless role

  Person.joins(:platform_memberships)
    .where(better_together_person_platform_memberships: { 
      platform_id: id,
      role_id: role.id 
    })
end
```

### Step 8: Seed Data & Translations (2 hours)

**Run the builder to create permissions and roles:**

```bash
bin/dc-run-dummy rails runner "
  platform = BetterTogether::Platform.find_by(host: true)
  builder = BetterTogether::AccessControlBuilder.new(platform)
  builder.seed_permissions!
  builder.seed_roles!
"
```

**Add translations** to `config/locales/en.yml`:

```yaml
en:
  better_together:
    platforms:
      show:
        analytics_access:
          title: "Analytics Access Management"
          grant_access: "Grant Analytics Access"
          select_person: "Select Person"
          choose_person: "Choose a person..."
          grant_button: "Grant Access"
          current_viewers: "Current Analytics Viewers"
          no_viewers: "No analytics viewers assigned"
          no_permission: "You don't have permission to manage analytics access"
          revoke_button: "Revoke Access"
          revoke_confirm: "Are you sure you want to revoke analytics access for %{name}?"
          table:
            person: "Person"
            granted_at: "Granted At"
            actions: "Actions"
```

Repeat for `es.yml` and `fr.yml`.

### Step 9: HostDashboard Security Fix (1 hour)

**CRITICAL:** This fixes high-severity security gap.

**File:** `app/controllers/better_together/host_dashboard_controller.rb`

Add authorization:

```ruby
module BetterTogether
  class HostDashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_access

    def show
      # existing implementation
    end

    private

    def authorize_access
      authorize :host_dashboard, :show?
    end
  end
end
```

### Step 10: Testing (3-4 hours)

#### Policy Specs

**File:** `spec/policies/better_together/host_dashboard_policy_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe BetterTogether::HostDashboardPolicy, type: :policy do
  subject(:policy) { described_class.new(user, :host_dashboard) }

  let(:platform) { create(:better_together_platform, host: true) }
  let(:user) { create(:user) }

  context 'when user is platform manager' do
    before do
      role = platform.roles.find_by(identifier: 'platform_manager')
      create(:better_together_person_platform_membership, person: user.person, platform: platform, role: role)
    end

    it { is_expected.to permit_action(:show) }
  end

  context 'when user is analytics viewer' do
    before do
      role = platform.roles.find_by(identifier: 'platform_analytics_viewer')
      create(:better_together_person_platform_membership, person: user.person, platform: platform, role: role)
    end

    it { is_expected.to forbid_action(:show) }
  end

  context 'when user has no platform roles' do
    it { is_expected.to forbid_action(:show) }
  end
end
```

**File:** `spec/policies/better_together/metrics/reports_policy_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe BetterTogether::Metrics::ReportsPolicy, type: :policy do
  subject(:policy) { described_class.new(user, [:metrics, :reports]) }

  let(:platform) { create(:better_together_platform, host: true) }
  let(:user) { create(:user) }

  context 'when user is analytics viewer' do
    before do
      role = platform.roles.find_by(identifier: 'platform_analytics_viewer')
      create(:better_together_person_platform_membership, person: user.person, platform: platform, role: role)
    end

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:download) }
  end

  context 'when user is platform manager' do
    before do
      role = platform.roles.find_by(identifier: 'platform_manager')
      create(:better_together_person_platform_membership, person: user.person, platform: platform, role: role)
    end

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:download) }
  end

  context 'when user has no metrics permissions' do
    it { is_expected.to forbid_actions(%i[index show create download]) }
  end
end
```

#### Request Specs

**File:** `spec/requests/better_together/metrics/reports_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe 'BetterTogether::Metrics::Reports', type: :request do
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:user) { create(:user) }

  describe 'GET /metrics/reports' do
    context 'when user is analytics viewer', :as_user do
      before do
        role = platform.roles.find_by(identifier: 'platform_analytics_viewer')
        create(:better_together_person_platform_membership, person: user.person, platform: platform, role: role)
      end

      it 'allows access' do
        get better_together.metrics_reports_path(locale: I18n.default_locale)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user has no permissions', :as_user do
      it 'denies access' do
        get better_together.metrics_reports_path(locale: I18n.default_locale)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user is not authenticated', :no_auth do
      it 'redirects to login' do
        get better_together.metrics_reports_path(locale: I18n.default_locale)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
```

#### Feature Specs

**File:** `spec/features/better_together/analytics_access_management_spec.rb`

```ruby
require 'rails_helper'

RSpec.feature 'Analytics Access Management', type: :feature, js: true do
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:platform_manager) { create(:user) }
  let(:regular_user) { create(:user) }

  before do
    manager_role = platform.roles.find_by(identifier: 'platform_manager')
    create(:better_together_person_platform_membership, 
      person: platform_manager.person, 
      platform: platform, 
      role: manager_role
    )
  end

  scenario 'Platform manager grants analytics access to a user' do
    capybara_login_as_platform_manager

    visit better_together.platform_path(platform, locale: I18n.default_locale)

    within '.analytics-access' do
      select regular_user.person.name, from: 'person_id'
      click_button 'Grant Access'
    end

    expect(page).to have_content(regular_user.person.name)
    expect(page).to have_button('Revoke Access')
  end

  scenario 'Analytics viewer can access metrics but not platform settings' do
    analytics_role = platform.roles.find_by(identifier: 'platform_analytics_viewer')
    create(:better_together_person_platform_membership,
      person: regular_user.person,
      platform: platform,
      role: analytics_role
    )

    login(regular_user.email, regular_user.password)

    visit better_together.metrics_reports_path(locale: I18n.default_locale)
    expect(page).to have_http_status(:success)

    visit better_together.host_dashboard_path(locale: I18n.default_locale)
    expect(page).to have_http_status(:forbidden)
  end
end
```

## Migration Path

### Development/Staging

1. **Pull latest code**
2. **Run builder to seed new permissions/roles:**
   ```bash
   bin/dc-run-dummy rails runner "
     platform = BetterTogether::Platform.find_by(host: true)
     builder = BetterTogether::AccessControlBuilder.new(platform)
     builder.seed_permissions!
     builder.seed_roles!
   "
   ```
3. **Verify in console:**
   ```bash
   bin/dc-run-dummy rails console
   > platform = BetterTogether::Platform.find_by(host: true)
   > platform.permissions.where(identifier: ['view_metrics_dashboard', 'create_metrics_reports', 'download_metrics_reports'])
   > platform.roles.find_by(identifier: 'platform_analytics_viewer')
   ```
4. **Test assignment:**
   - Log in as platform manager
   - Navigate to Platform show page
   - Grant analytics access to a test user
   - Log in as that user
   - Verify metrics access works
   - Verify platform dashboard returns 403

### Production

1. **Deploy code**
2. **Run seed rake task or runner (same as above)**
3. **Test with staging user first**
4. **Grant access to real analytics viewer**
5. **Monitor logs for authorization errors**

## Rollback Plan

If issues arise:

1. **Remove analytics viewer memberships:**
   ```ruby
   role = BetterTogether::Role.find_by(identifier: 'platform_analytics_viewer')
   BetterTogether::PersonPlatformMembership.where(role: role).destroy_all
   ```

2. **Revert routing constraint** (restore `manage_platform` requirement)

3. **Redeploy previous version**

4. **Permissions and roles are safe to leave** - they won't cause issues if unused

## Success Criteria

### For Platform Managers
- ✅ Can see "Analytics Access Management" section on platform page
- ✅ Can select a person and grant analytics access
- ✅ Can see list of current analytics viewers
- ✅ Can revoke analytics access
- ✅ Still have full metrics access themselves

### For Analytics Viewers  
- ✅ Can see "Analytics" in navigation
- ✅ Can access metrics dashboard
- ✅ Can create new reports (all types)
- ✅ Can download report CSVs
- ✅ **Cannot** access platform settings
- ✅ **Cannot** access user management
- ✅ **Cannot** access host dashboard

### For Regular Users
- ✅ **Cannot** see "Analytics" in navigation
- ✅ Get 403 when attempting to access metrics URLs directly
- ✅ Cannot see analytics access UI

## Post-MVP Enhancements

Once MVP is deployed and stable, consider:

1. **Time-Based Memberships** (from comprehensive plan Phase 2)
   - Add expires_at to memberships
   - Auto-renewal workflows
   - Role request system

2. **Audit Logging** (Phase 3)
   - PaperTrail integration
   - Anonymous audit logs
   - Report generation

3. **Section Access UI** (Phase 4)
   - Extensible permission assignment
   - Multi-section role builder
   - Custom role creation

4. **Cache Improvements** (Phase 5)
   - Reduce TTL to 5 minutes
   - Add invalidation hooks
   - Filter only active memberships

See `docs/implementation/granular_metrics_access_and_time_based_rbac.md` for complete details.
