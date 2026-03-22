# Test Pollution Mitigation Plan

## Problem Summary
37 specs pass individually but fail in parallel execution due to test pollution vulnerabilities:
- OAuth callback specs (26 failures)
- GitHub OAuth integration (4 failures)
- Event recurrence specs (3 failures)
- Agreement registration (2 failures)
- Platform privacy/invitation (2 failures)

## Root Causes

### 1. Global OmniAuth State
**Problem:** `OmniAuth.config` is shared across parallel workers
**Impact:** Workers overwrite each other's test mode and mock auth

### 2. Race Conditions in User Creation
**Problem:** Manual `delete_all` calls race with DatabaseCleaner
**Impact:** OAuth signup expects no users, but parallel worker created one

### 3. Lazy Evaluation of Shared Resources
**Problem:** `let` doesn't guarantee platform exists before test runs
**Impact:** Multiple workers try to create host platform simultaneously

### 4. Non-Unique Test Data
**Problem:** Faker uniqueness is per-process, not per-worker
**Impact:** Duplicate identifiers cause constraint violations

### 5. Time-Based Instability
**Problem:** Relative times differ across workers
**Impact:** DST transitions and timing cause flaky failures

## Mitigation Strategies

### Strategy 1: Isolate OmniAuth State

```ruby
# spec/support/omniauth_test_helpers.rb
module OmniauthTestHelpers
  def isolate_omniauth
    around do |example|
      # Save original state
      original_test_mode = OmniAuth.config.test_mode
      original_mocks = OmniAuth.config.mock_auth.to_hash.dup
      
      # Run test in isolation
      example.run
      
      # Restore original state
      OmniAuth.config.test_mode = original_test_mode
      OmniAuth.config.mock_auth = OmniAuth::AuthHash.new(original_mocks)
    end
  end
end

RSpec.configure do |config|
  config.include OmniauthTestHelpers, :omniauth
end
```

**Usage:**
```ruby
RSpec.describe 'GitHub OAuth', :omniauth do
  isolate_omniauth
  
  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = auth_hash
  end
  
  # Tests run in isolation
end
```

### Strategy 2: Use Unique Identifiers Per Test

```ruby
# spec/support/unique_test_data.rb
module UniqueTestData
  def unique_email
    "test-#{SecureRandom.uuid}@example.com"
  end
  
  def unique_oauth_uid
    "oauth-#{SecureRandom.uuid}"
  end
  
  def unique_identifier(prefix = 'test')
    "#{prefix}-#{SecureRandom.hex(10)}"
  end
end

RSpec.configure do |config|
  config.include UniqueTestData
end
```

**Usage:**
```ruby
let(:github_auth_hash) do
  OmniAuth::AuthHash.new({
    provider: 'github',
    uid: unique_oauth_uid,  # Unique per test
    info: { email: unique_email }  # Unique per test
  })
end
```

### Strategy 3: Eager Load Shared Resources

```ruby
# Change from lazy let to eager let!
# BEFORE (vulnerable):
let(:platform) { configure_host_platform }

# AFTER (robust):
let!(:platform) { configure_host_platform }

# Or use before block for clarity:
before(:context) do
  @platform = configure_host_platform
end

let(:platform) { @platform }
```

### Strategy 4: Remove Manual Cleanup

```ruby
# REMOVE manual delete_all calls - let DatabaseCleaner handle it
# BEFORE (vulnerable):
before do
  BetterTogether.user_class.where(email: 'user@example.test').delete_all
  BetterTogether::PersonPlatformIntegration.where(...).delete_all
end

# AFTER (robust):
before do
  # Let DatabaseCleaner handle cleanup
  # Use unique identifiers to prevent conflicts
end
```

### Strategy 5: Freeze Time for Consistency

```ruby
# spec/support/time_helpers.rb
module TimeHelpers
  def with_frozen_time(time_string = '2026-02-15 10:00:00', &block)
    travel_to(Time.zone.parse(time_string), &block)
  end
end

RSpec.configure do |config|
  config.include TimeHelpers
  config.include ActiveSupport::Testing::TimeHelpers
end
```

**Usage:**
```ruby
describe 'Event recurrence' do
  around do |example|
    travel_to(Time.zone.parse('2026-02-15 10:00:00')) do
      example.run
    end
  end
  
  let(:event_params) do
    {
      starts_at: Time.zone.parse('2026-02-22 10:00:00'),  # Explicit, not relative
      ends_at: Time.zone.parse('2026-02-22 12:00:00')
    }
  end
end
```

### Strategy 6: Add Aggregate Failures

```ruby
# Add :aggregate_failures to show all assertion failures
it 'creates user with correct attributes', :aggregate_failures do
  get :github
  
  user = BetterTogether.user_class.last
  expect(user.email).to eq('test@example.com')
  expect(user.confirmed_at).to be_present
  expect(user.person.name).to eq('Test User')
  expect(user.person.handle).to eq('testuser')
end
```

### Strategy 7: Tag for Sequential Execution (Temporary)

```ruby
# As a last resort, disable parallel execution for problematic specs
RSpec.describe 'GitHub OAuth Integration', :no_parallel do
  # These tests will run sequentially
end
```

**Configure in .rspec_parallel:**
```
--tag ~no_parallel
```

**Run no_parallel specs separately:**
```bash
bin/dc-run bundle exec rspec --tag no_parallel
```

## Implementation Priority

### Phase 1: Quick Wins (Immediate)
1. ✅ Add `:aggregate_failures` to all multi-assertion tests
2. ✅ Replace Faker with SecureRandom for unique identifiers
3. ✅ Change `let` to `let!` for shared resources (platform, community)
4. ✅ Remove manual `delete_all` calls

### Phase 2: OmniAuth Isolation (High Priority)
1. ✅ Create `isolate_omniauth` helper
2. ✅ Apply to all OAuth specs
3. ✅ Test in parallel execution

### Phase 3: Time Stability (Medium Priority)
1. ✅ Add `travel_to` blocks to time-sensitive specs
2. ✅ Replace relative times with explicit timestamps
3. ✅ Test DST transitions explicitly

### Phase 4: Sequential Fallback (If Needed)
1. ⚠️ Tag remaining problematic specs with `:no_parallel`
2. ⚠️ Update CI to run tagged specs separately
3. ⚠️ Create issue to properly fix and remove tag

## Testing the Fixes

### Before Each Fix
```bash
# Run failing spec individually (should pass)
bin/dc-run bundle exec prspec spec/controllers/.../omniauth_callbacks_controller_spec.rb:128

# Run full suite (currently fails)
bin/dc-run bin/ci
```

### After Each Fix
```bash
# Run full suite 3 times to verify consistency
bin/dc-run bin/ci  # Run 1
bin/dc-run bin/ci  # Run 2
bin/dc-run bin/ci  # Run 3

# All runs should have same results
```

### Success Criteria
- ✅ All 37 failing specs pass in parallel execution
- ✅ Results are consistent across multiple runs
- ✅ No new failures introduced
- ✅ Test execution time doesn't significantly increase

## Files to Modify

### Create New Support Files
- `spec/support/omniauth_test_helpers.rb` - OmniAuth isolation
- `spec/support/unique_test_data.rb` - Unique identifier generators
- `spec/support/time_helpers.rb` - Frozen time helpers (may already exist)

### Modify Existing Specs
- `spec/controllers/better_together/users/omniauth_callbacks_controller_spec.rb`
- `spec/controllers/better_together/users/omniauth_authentication_flows_controller_spec.rb`
- `spec/features/github_oauth_integration_spec.rb`
- `spec/requests/better_together/events/recurrence_form_integration_spec.rb`
- All other failing specs from CI output

### Update Configuration
- `spec/rails_helper.rb` - Include new support modules
- `.rspec_parallel` - Add no_parallel exclusion if needed

## Rollback Plan

If fixes cause new issues:
1. Revert to `main` branch
2. Apply fixes one at a time
3. Test each fix individually
4. Identify problematic change
5. Refine approach

## Next Steps

1. Create support helper files
2. Update OAuth specs with unique identifiers and isolation
3. Update recurrence specs with frozen time
4. Run parallel CI to verify fixes
5. Document any remaining issues
