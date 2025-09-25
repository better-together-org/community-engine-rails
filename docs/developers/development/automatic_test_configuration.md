# Automatic Test Configuration

This system provides automatic setup for request, controller, and feature tests, eliminating the need for manual `configure_host_platform` and authentication setup in most test files.

## Features

### 1. Automatic Host Platform Setup
- **Default**: All request, controller, and feature tests automatically get host platform setup
- **Skip**: Use `:skip_host_setup` tag to skip automatic configuration (useful for testing host setup wizard)

### 2. Automatic Authentication
Multiple ways to configure authentication:

#### Tag-Based Authentication
```ruby
RSpec.describe 'SomeController', :as_platform_manager do
  # All tests in this describe block will be authenticated as platform manager
end

RSpec.describe 'SomeController', :as_user do  
  # All tests in this describe block will be authenticated as regular user
end

RSpec.describe 'SomeController', :no_auth do
  # All tests in this describe block will remain unauthenticated
end
```

#### Description-Based Authentication
The system automatically detects keywords in `describe` and `context` blocks:

```ruby
# These automatically authenticate as platform manager:
context 'as platform manager' do
context 'as admin' do
context 'as manager' do
context 'as host admin' do

# These automatically authenticate as regular user:
context 'as authenticated user' do
context 'when logged in' do  
context 'when signed in' do
context 'as user' do
context 'as member' do
```

#### Example-Level Tags
```ruby
it 'does something', :as_platform_manager do
  # This specific test runs as platform manager
end

it 'does something else', :as_user do
  # This specific test runs as regular user  
end
```

## Migration Guide

### Before (Manual Configuration)
```ruby
RSpec.describe 'SomeController' do
  before do
    configure_host_platform
    login('manager@example.test', 'password12345') 
  end
  
  # tests...
end
```

### After (Automatic Configuration)
```ruby
# Option 1: Using tags
RSpec.describe 'SomeController', :as_platform_manager do
  # tests...
end

# Option 2: Using description
RSpec.describe 'SomeController' do
  context 'as platform manager' do
    # tests...
  end
end
```

## Special Cases

### Testing Setup Wizard or Onboarding
```ruby
RSpec.describe 'SetupWizardController', :skip_host_setup, :no_auth do
  # These tests won't get automatic host platform or authentication
  # Perfect for testing initial setup flows
end
```

### Mixed Authentication in Same File
```ruby
RSpec.describe 'SomeController' do
  context 'as platform manager' do
    it 'allows admin actions' do
      # Automatically authenticated as platform manager
    end
  end
  
  context 'as regular user' do  
    it 'restricts admin actions' do
      # Automatically authenticated as regular user
    end
  end
  
  context 'without authentication', :no_auth do
    it 'redirects to login' do
      # No authentication
    end
  end
end
```

## Keywords Reference

### Platform Manager Keywords
- "platform manager"
- "admin" 
- "manager"
- "host admin"
- "system admin"

### Regular User Keywords  
- "authenticated"
- "logged in"
- "signed in"
- "user"
- "member"

## Available Tags

- `:as_platform_manager` - Login as platform manager
- `:as_user` - Login as regular user
- `:authenticated` - Login as regular user (alias for :as_user)
- `:no_auth` - Skip authentication
- `:unauthenticated` - Skip authentication (alias for :no_auth)
- `:skip_host_setup` - Skip automatic host platform configuration
- `:platform_manager` - Login as platform manager (alias for :as_platform_manager)
- `:user` - Login as regular user (alias for :as_user)

## Test Types Covered

Automatic configuration applies to:
- `:type => :request`
- `:type => :controller` 
- `:type => :feature`

Other test types (`:model`, `:job`, `:mailer`, etc.) are unaffected.
