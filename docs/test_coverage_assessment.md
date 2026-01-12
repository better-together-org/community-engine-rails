# Test Coverage Assessment - OAuth, Notifications & Preferences Features

**Date**: January 5, 2026  
**Session**: Recent OAuth security, notifications, and self-contained preferences work

## Executive Summary

This assessment identifies test coverage gaps for recent feature work across three major areas:
1. OAuth security enhancements (email mismatch prevention, last integration protection)
2. Notification system improvements (caching, badge updates, mark as read)
3. Self-contained preference fields (individual AJAX saves, Stimulus controllers)

**Overall Status**: 🟡 **Moderate Coverage** - Core happy paths covered, critical edge cases missing

---

## Feature-by-Feature Coverage Analysis

### 1. OAuth Email Mismatch Security ❌ **NO COVERAGE**

**Implementation**: `app/models/concerns/better_together/devise_user.rb` (lines 75-89)

**What It Does**: Prevents User A (signed in) from linking User B's OAuth account by checking if OAuth email belongs to different user

**Existing Coverage**: ❌ None
- No spec tests email mismatch scenario
- `devise_user_spec.rb` tests happy paths only

**Missing Tests**:
```ruby
# CRITICAL: Security vulnerability if untested
context 'when current_user tries to link another user\'s OAuth account' do
  let(:user_a) { create(:user, email: 'user_a@example.com') }
  let(:user_b) { create(:user, email: 'user_b@example.com') }
  let(:oauth_auth_for_user_b) do
    # OAuth data with user_b's email
  end

  it 'raises ArgumentError preventing account linkage' do
    expect {
      User.from_omniauth(
        person_platform_integration: nil,
        auth: oauth_auth_for_user_b,
        current_user: user_a
      )
    }.to raise_error(ArgumentError, /email_mismatch/)
  end

  it 'includes provider name and email in error message' do
    # Test error message contains interpolated values
  end
end
```

**Priority**: 🔴 **CRITICAL** - Security feature must be tested

---

### 2. Prevent Last OAuth Integration Deletion ❌ **NO COVERAGE**

**Implementation**: `app/controllers/better_together/person_platform_integrations_controller.rb` (lines 64-70, 121-142)

**What It Does**: Prevents OauthUser (no password) from deleting their last integration (would lock them out)

**Existing Coverage**: ❌ None
- `person_platform_integrations_spec.rb` tests basic destroy action
- Doesn't test OauthUser scenario or count check

**Missing Tests**:
```ruby
describe 'DELETE /destroy for OauthUser', :as_oauth_user do
  context 'when OauthUser has only one integration' do
    let(:oauth_user) { create(:oauth_user) } # Type = 'BetterTogether::OauthUser'
    let(:last_integration) { create(:person_platform_integration, user: oauth_user) }

    it 'prevents deletion with alert message' do
      delete person_platform_integration_path(last_integration)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(flash[:alert]).to match(/cannot_delete_last_oauth/)
    end

    it 'does not destroy the integration' do
      expect {
        delete person_platform_integration_path(last_integration)
      }.not_to change(PersonPlatformIntegration, :count)
    end
  end

  context 'when OauthUser has multiple integrations' do
    let(:oauth_user) { create(:oauth_user) }
    let!(:integration1) { create(:person_platform_integration, user: oauth_user) }
    let!(:integration2) { create(:person_platform_integration, :facebook, user: oauth_user) }

    it 'allows deletion when user has other integrations' do
      expect {
        delete person_platform_integration_path(integration1)
      }.to change(PersonPlatformIntegration, :count).by(-1)
    end
  end

  context 'when regular User (with password) has one integration' do
    let(:regular_user) { create(:user, password: 'SecurePass123!') }
    let(:only_integration) { create(:person_platform_integration, user: regular_user) }

    it 'allows deletion for users with password' do
      expect {
        delete person_platform_integration_path(only_integration)
      }.to change(PersonPlatformIntegration, :count).by(-1)
    end
  end
end
```

**Priority**: 🔴 **CRITICAL** - User lockout prevention must be tested

---

### 3. Notification Badge Updates via Turbo Streams ⚠️ **PARTIAL COVERAGE**

**Implementation**: 
- `app/controllers/better_together/notifications_controller.rb` (lines 62-110)
- `app/javascript/controllers/better_together/integration_notifications_controller.js` (lines 38-51)

**What It Does**: Updates notification badge count in navbar when notifications marked as read

**Existing Coverage**: ⚠️ Partial
- `notifications_controller_spec.rb` tests mark_as_read action
- Doesn't test Turbo stream badge update or counter logic

**Missing Tests**:
```ruby
describe 'PATCH #mark_as_read with badge updates' do
  it 'returns turbo stream with badge update' do
    notification = create(:noticed_notification, recipient: person, read_at: nil)
    
    patch mark_as_read_notification_path(notification), 
          headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    expect(response.body).to include('turbo-stream action="replace" target="person_notification_count"')
  end

  it 'removes badge when last unread notification marked read' do
    last_unread = create(:noticed_notification, recipient: person, read_at: nil)
    
    patch mark_as_read_notification_path(last_unread),
          headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    expect(response.body).to include('turbo-stream action="remove" target="person_notification_count"')
  end

  it 'updates badge count when multiple unread remain' do
    create_list(:noticed_notification, 3, recipient: person, read_at: nil)
    notification_to_mark = person.notifications.first
    
    patch mark_as_read_notification_path(notification_to_mark),
          headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    # Should show badge with count "2"
    expect(response.body).to include('2</span>')
  end
end

describe 'POST #mark_all_as_read with badge updates' do
  it 'removes badge after marking all read' do
    create_list(:noticed_notification, 5, recipient: person, read_at: nil)
    
    post mark_all_as_read_notifications_path,
         headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    expect(response.body).to include('turbo-stream action="remove" target="person_notification_count"')
  end
end
```

**Priority**: 🟡 **MEDIUM** - Important UX feature, existing partial coverage

---

### 4. Integration Notification 5-Second Threshold ❌ **NO COVERAGE**

**Implementation**: `app/controllers/better_together/settings_controller.rb` (lines 18-31)

**What It Does**: Excludes notifications created <5 seconds ago from auto-mark as read (prevents marking notification for integration just created)

**Existing Coverage**: ❌ None

**Missing Tests**:
```ruby
describe 'POST #mark_integration_notifications_read' do
  context 'with notifications older than 5 seconds' do
    it 'marks old integration notifications as read' do
      old_notification = create(:person_platform_integration_created_notification,
                                recipient: person,
                                created_at: 10.seconds.ago)
      
      post mark_integration_notifications_read_settings_path
      
      expect(old_notification.reload.read_at).to be_present
    end
  end

  context 'with notifications created less than 5 seconds ago' do
    it 'does not mark recent notifications as read' do
      recent_notification = create(:person_platform_integration_created_notification,
                                    recipient: person,
                                    created_at: 2.seconds.ago)
      
      post mark_integration_notifications_read_settings_path
      
      expect(recent_notification.reload.read_at).to be_nil
    end

    it 'returns correct count excluding recent notifications' do
      create(:person_platform_integration_created_notification,
             recipient: person, created_at: 10.seconds.ago)
      create(:person_platform_integration_created_notification,
             recipient: person, created_at: 2.seconds.ago)
      
      post mark_integration_notifications_read_settings_path
      
      expect(JSON.parse(response.body)['marked_read']).to eq(1)
    end
  end
end
```

**Priority**: 🟡 **MEDIUM** - UX improvement, prevents confusing behavior

---

### 5. Notification Cache Invalidation ⚠️ **PARTIAL COVERAGE**

**Implementation**:
- `app/controllers/better_together/notifications_controller.rb` (lines 21, cache key includes total_count)
- `app/models/better_together/person_platform_integration.rb` (lines 28, 191-199, after_destroy callback)

**What It Does**: Invalidates notification dropdown cache when integration deleted or notification count changes

**Existing Coverage**: ⚠️ Partial
- Cache behavior tested in `notifications_controller_spec.rb`
- Callback not tested

**Missing Tests**:
```ruby
# In person_platform_integration_spec.rb
describe 'cache invalidation callbacks' do
  it 'clears notification caches after integration destroyed' do
    integration = create(:person_platform_integration, user: user)
    cache_key_pattern = "notifications_dropdown/#{user.person.id}/*"
    
    # Populate cache
    Rails.cache.write("notifications_dropdown/#{user.person.id}/123/5/10", 'cached_content')
    
    expect {
      integration.destroy
    }.to change {
      Rails.cache.exist?("notifications_dropdown/#{user.person.id}/123/5/10")
    }.from(true).to(false)
  end
end

# In notifications_controller_spec.rb
describe 'cache key with total_count' do
  it 'changes cache key when total notification count changes' do
    get dropdown_notifications_path
    first_cache_key = assigns(:cache_key)
    
    # Delete a notification
    person.notifications.last.destroy
    
    get dropdown_notifications_path
    second_cache_key = assigns(:cache_key)
    
    expect(first_cache_key).not_to eq(second_cache_key)
  end
end
```

**Priority**: 🟢 **LOW** - Nice to have, existing coverage adequate

---

### 6. Self-Contained Preference Fields ❌ **NO COVERAGE**

**Implementation**:
- `app/helpers/better_together/settings_helper.rb` (162 lines, preference_field helper)
- `app/javascript/controllers/better_together/preference_field_controller.js` (139 lines)
- `app/javascript/controllers/better_together/preference_flash_controller.js` (73 lines)
- `app/controllers/better_together/people_controller.rb` (lines 61-106, JSON responses)

**What It Does**: Individual preference fields with save/cancel buttons, AJAX updates, change tracking

**Existing Coverage**: ❌ None for new functionality
- `settings_preferences_spec.rb` tests full form submission (HTML)
- Doesn't test individual field AJAX saves or JSON responses

**Missing Tests**:

#### Request Specs (JSON API)
```ruby
describe 'PATCH /people/:id for individual preference' do
  context 'with JSON format' do
    it 'updates single preference via JSON' do
      patch person_path(person, locale: I18n.locale),
            params: { person: { locale: 'es' } },
            headers: { 'Accept' => 'application/json' }
      
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to include(
        'success' => true,
        'message' => I18n.t('better_together.settings.index.preferences.saved')
      )
      expect(person.reload.locale).to eq('es')
    end

    it 'returns errors for invalid preference via JSON' do
      patch person_path(person, locale: I18n.locale),
            params: { person: { locale: 'invalid' } },
            headers: { 'Accept' => 'application/json' }
      
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
      expect(json['errors']).to be_present
    end

    it 'handles boolean toggle preferences via JSON' do
      person.update(notify_by_email: true)
      
      patch person_path(person, locale: I18n.locale),
            params: { person: { notify_by_email: '0' } },
            headers: { 'Accept' => 'application/json' }
      
      expect(person.reload.notify_by_email).to be false
    end
  end
end
```

#### Helper Specs
```ruby
# spec/helpers/better_together/settings_helper_spec.rb (NEW FILE)
RSpec.describe BetterTogether::SettingsHelper do
  let(:person) { create(:better_together_person, locale: 'en', time_zone: 'UTC') }

  describe '#preference_field' do
    it 'renders field with Stimulus controller' do
      html = helper.preference_field(person, :locale, type: :select)
      
      expect(html).to include('data-controller="better-together--preference-field"')
      expect(html).to include('data-better-together--preference-field-url-value')
    end

    it 'includes save and cancel buttons' do
      html = helper.preference_field(person, :locale, type: :select)
      
      expect(html).to include('Save')
      expect(html).to include('Cancel')
    end

    it 'renders different field types correctly' do
      select_html = helper.preference_field(person, :locale, type: :select)
      expect(select_html).to include('<select')
      
      time_zone_html = helper.preference_field(person, :time_zone, type: :time_zone)
      expect(time_zone_html).to include('time_zone_select')
      
      toggle_html = helper.preference_field(person, :notify_by_email, type: :toggle)
      expect(toggle_html).to include('form-check-input')
    end

    it 'includes icon class when provided' do
      html = helper.preference_field(person, :locale, 
                                      type: :select, 
                                      icon_class: 'fa-solid fa-language')
      
      expect(html).to include('fa-solid fa-language')
    end
  end
end
```

#### Feature Specs (Stimulus Integration)
```ruby
# spec/features/better_together/preference_field_interactions_spec.rb (NEW FILE)
RSpec.feature 'Self-contained Preference Fields', :js do
  let(:user) { create(:user) }
  let(:person) { user.person }

  before do
    sign_in user
    visit settings_path
  end

  scenario 'user changes language preference' do
    within '#preferences' do
      # Find language field
      select 'Español', from: 'person_locale'
      
      # Save button should appear
      expect(page).to have_button('Save', visible: true)
      
      # Click save
      click_button 'Save'
      
      # Flash message should appear
      expect(page).to have_content(I18n.t('better_together.settings.index.preferences.saved'))
      
      # Save button should hide
      expect(page).to have_button('Save', visible: false)
    end
    
    # Verify persistence
    expect(person.reload.locale).to eq('es')
  end

  scenario 'user cancels preference change' do
    original_locale = person.locale
    
    within '#preferences' do
      select 'Français', from: 'person_locale'
      
      # Cancel button should appear
      expect(page).to have_button('Cancel', visible: true)
      
      # Click cancel
      click_button 'Cancel'
      
      # Field should revert to original value
      expect(page).to have_select('person_locale', selected: I18n.t("locale.#{original_locale}"))
      
      # Buttons should hide
      expect(page).to have_button('Save', visible: false)
    end
    
    # Verify no change persisted
    expect(person.reload.locale).to eq(original_locale)
  end

  scenario 'toolbar appears only when field changes' do
    within '#preferences' do
      # Toolbar should be hidden initially
      toolbar = find('.preference-toolbar', visible: false)
      expect(toolbar).not_to be_visible
      
      # Change field
      select 'Español', from: 'person_locale'
      
      # Toolbar should become visible
      expect(toolbar).to be_visible
    end
  end
end
```

**Priority**: 🟡 **MEDIUM** - Core feature, needs comprehensive coverage

---

### 7. Stimulus Controller Testing ❌ **NO COVERAGE**

**Implementation**:
- `preference_field_controller.js` - Change tracking, AJAX save/cancel
- `preference_flash_controller.js` - Event-based flash messages
- `integration_notifications_controller.js` - Badge update logic

**Existing Coverage**: ❌ None (no JavaScript test framework)

**Recommendation**: Set up JavaScript testing

**Missing Infrastructure**:
```bash
# Option 1: Jest + Testing Library
yarn add --dev jest @testing-library/dom @testing-library/jest-dom

# Option 2: Vitest (faster, ES modules native)
yarn add --dev vitest @vitest/ui jsdom
```

**Example Test Structure**:
```javascript
// spec/javascript/controllers/better_together/preference_field_controller.spec.js
import { Application } from '@hotwired/stimulus'
import PreferenceFieldController from 'app/javascript/controllers/better_together/preference_field_controller'

describe('PreferenceFieldController', () => {
  let application
  let controller

  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="better-together--preference-field"
           data-better-together--preference-field-url-value="/people/123">
        <input type="text" 
               data-better-together--preference-field-target="field"
               data-action="change->better-together--preference-field#fieldChanged"
               value="original">
        <div class="preference-toolbar" 
             data-better-together--preference-field-target="toolbar"
             style="visibility: hidden;">
          <button data-action="click->better-together--preference-field#save">Save</button>
          <button data-action="click->better-together--preference-field#cancel">Cancel</button>
        </div>
      </div>
    `

    application = Application.start()
    application.register('better-together--preference-field', PreferenceFieldController)
  })

  afterEach(() => {
    application.stop()
  })

  test('shows toolbar when field changes', () => {
    const field = document.querySelector('[data-better-together--preference-field-target="field"]')
    const toolbar = document.querySelector('[data-better-together--preference-field-target="toolbar"]')

    field.value = 'changed'
    field.dispatchEvent(new Event('change'))

    expect(toolbar.style.visibility).toBe('visible')
  })

  test('restores original value on cancel', () => {
    const field = document.querySelector('[data-better-together--preference-field-target="field"]')
    const cancelButton = document.querySelector('button:last-child')

    field.value = 'changed'
    field.dispatchEvent(new Event('change'))
    
    cancelButton.click()

    expect(field.value).toBe('original')
  })

  test('makes AJAX request on save', async () => {
    global.fetch = jest.fn(() => 
      Promise.resolve({
        ok: true,
        json: () => Promise.resolve({ success: true, message: 'Saved' })
      })
    )

    const saveButton = document.querySelector('button:first-child')
    saveButton.click()

    await new Promise(resolve => setTimeout(resolve, 0))

    expect(global.fetch).toHaveBeenCalledWith(
      '/people/123',
      expect.objectContaining({
        method: 'PATCH',
        headers: expect.objectContaining({
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json'
        })
      })
    )
  })
})
```

**Priority**: 🟢 **LOW** - Nice to have, covered by feature specs

---

## Summary by Priority

### 🔴 CRITICAL (Implement First)
1. **OAuth Email Mismatch Security** - Prevents unauthorized account linking
2. **Last OAuth Integration Protection** - Prevents user lockout

### 🟡 MEDIUM (Implement Second)
3. **Self-Contained Preference Fields** - Core UX feature needs coverage
4. **Notification Badge Updates** - Important UX, partial coverage exists
5. **5-Second Notification Threshold** - UX improvement

### 🟢 LOW (Optional)
6. **Cache Invalidation** - Existing coverage adequate
7. **Stimulus Controllers** - Can be covered via feature specs

---

## Recommended Implementation Plan

### Phase 1: Security Critical (Week 1)
**Goal**: Ensure OAuth security features are bulletproof

1. **OAuth Email Mismatch Tests** (4 hours)
   - Model specs in `devise_user_spec.rb`
   - Test ArgumentError raised with correct message
   - Test security edge cases (nil email, case sensitivity)

2. **Last Integration Protection Tests** (4 hours)
   - Request specs in `person_platform_integrations_spec.rb`
   - Test OauthUser vs regular User behavior
   - Test integration count thresholds
   - Test both HTML and Turbo Stream responses

**Deliverable**: 100% coverage of security-critical paths

### Phase 2: Core Features (Week 2)
**Goal**: Cover primary user-facing functionality

3. **Preference Field AJAX Tests** (6 hours)
   - JSON API request specs
   - Error handling for invalid inputs
   - Boolean toggle handling
   - Helper specs for field rendering

4. **Notification Badge Update Tests** (4 hours)
   - Turbo stream response specs
   - Badge count logic
   - Remove vs update scenarios

**Deliverable**: Request spec coverage for AJAX interactions

### Phase 3: UX Polish (Week 3)
**Goal**: Comprehensive feature spec coverage

5. **Preference Field Feature Specs** (8 hours)
   - JavaScript-enabled feature tests
   - Save/cancel button interactions
   - Field change detection
   - Flash message display

6. **Notification Threshold Tests** (2 hours)
   - Time-based filtering logic
   - Marked count accuracy

**Deliverable**: End-to-end user workflow coverage

### Phase 4: Optional Enhancements (Week 4)
**Goal**: Complete coverage with JS testing

7. **Set up JavaScript Testing** (4 hours)
   - Install Vitest or Jest
   - Configure test environment
   - Write controller unit tests

8. **Cache Invalidation Edge Cases** (2 hours)
   - Callback execution verification
   - Cache key variation tests

**Deliverable**: Full stack testing infrastructure

---

## Metrics & Success Criteria

### Coverage Targets
- **Security Features**: 100% (no gaps allowed)
- **Core Features**: 90%+ (all happy + critical edge cases)
- **UX Features**: 80%+ (happy paths + common errors)
- **JavaScript**: 70%+ (if framework implemented)

### Quality Standards
- All tests follow automatic_test_configuration.rb patterns
- Use HTML assertion helpers for content checks
- Request specs for all AJAX endpoints
- Feature specs for JavaScript interactions
- Proper use of metadata tags (:as_user, :as_platform_manager, etc.)

### Definition of Done
- [ ] All CRITICAL tests implemented and passing
- [ ] All MEDIUM tests implemented and passing
- [ ] CI pipeline passes with new tests
- [ ] Test execution time < 5 minutes total
- [ ] No pending/skipped specs
- [ ] Documentation updated with testing approach

---

## Additional Recommendations

### 1. Factory Enhancements
Create `oauth_user` factory:
```ruby
# spec/factories/better_together/users.rb
factory :oauth_user, parent: :user, class: 'BetterTogether::OauthUser' do
  type { 'BetterTogether::OauthUser' }
  password { nil }
  
  after(:create) do |user|
    create(:person_platform_integration, user: user)
  end
end
```

### 2. Shared Examples
Extract common integration tests:
```ruby
# spec/support/shared_examples/turbo_streamable.rb
RSpec.shared_examples 'turbo streamable response' do |target_id|
  it 'returns turbo stream format' do
    expect(response.content_type).to match(/turbo-stream/)
  end

  it "includes target #{target_id}" do
    expect(response.body).to include("target=\"#{target_id}\"")
  end
end
```

### 3. Test Data Builders
For complex notification scenarios:
```ruby
# spec/support/builders/notification_builder.rb
class NotificationBuilder
  def self.create_integration_notification_scenario(person, age_seconds: 10)
    integration = create(:person_platform_integration, user: person.user)
    create(:person_platform_integration_created_notification,
           recipient: person,
           record: integration,
           created_at: age_seconds.seconds.ago)
  end
end
```

---

## Next Steps

1. **Review this assessment** with team
2. **Prioritize Phase 1** (Security Critical) for immediate implementation
3. **Assign ownership** for each test suite
4. **Set milestone dates** for each phase
5. **Track coverage** using SimpleCov
6. **Integrate into CI/CD** pipeline

**Estimated Total Effort**: 30-40 hours over 4 weeks
