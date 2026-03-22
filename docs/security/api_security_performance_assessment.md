# API Security & Performance Assessment

**Date:** January 29, 2026  
**Scope:** Better Together Community Engine REST API  
**Focus:** Security vulnerabilities, rate limiting, OAuth2 implementation

## Executive Summary

### Current State: ✅ Good Foundation
- **Rate Limiting:** ✅ Rack::Attack configured with Redis backing
- **Authentication:** ✅ JWT (warden-jwt_auth) for user sessions
- **Authorization:** ✅ Pundit policies enforced
- **CORS:** ✅ Configured with environment-based origins
- **CSRF:** ✅ Protected (disabled for JSON API requests)

### Critical Gaps: 🔴 Requires Immediate Attention
1. **No OAuth2/application-level authentication** - Only user-based JWT
2. **No API key management** for third-party applications
3. **No granular permission scopes** for API access
4. **Rate limits not API-specific** - Same limits for web and API
5. **No token refresh mechanism** - JWT tokens don't expire/refresh
6. **Missing API versioning strategy** for breaking changes

---

## 1. Current Security Analysis

### 1.1 Authentication Stack

#### ✅ Strengths
```ruby
# JWT-based authentication via warden-jwt_auth
class User < ApplicationRecord
  devise :jwt_authenticatable,
         jwt_revocation_strategy: JwtDenylist
end

# Pundit authorization on all endpoints
class ApplicationController < ::JSONAPI::ResourceController
  before_action :authenticate_user!
  include Pundit::Authorization
end
```

**Benefits:**
- Stateless authentication
- Token revocation via denylist
- Policy-based authorization
- Automatic 404 conversion for unauthorized access

#### 🔴 Vulnerabilities

1. **No Token Expiration Strategy**
```ruby
# config/initializers/devise.rb
# Missing: jwt.expiration_time configuration
# Current: Tokens don't expire unless manually revoked
```

**Risk:** Stolen tokens remain valid indefinitely  
**Fix:** Add token expiration + refresh mechanism

2. **No Application-Level Authentication**
```ruby
# Current: Only user (person) authentication
# Missing: Third-party app authentication
# Missing: API key management
# Missing: OAuth2 client credentials flow
```

**Risk:** Cannot securely integrate third-party applications  
**Impact:** No mobile apps, no partner integrations, no webhook consumers

3. **Insufficient Rate Limiting Granularity**
```ruby
# config/initializers/rack_attack.rb
throttle('req/ip', limit: 300, period: 5.minutes, &:ip)
throttle('logins/ip', limit: 5, period: 20.seconds)
```

**Issues:**
- Same limits for authenticated/unauthenticated requests
- No per-user or per-application rate limits
- No endpoint-specific throttling
- IP-based only (doesn't account for shared IPs/NAT)

### 1.2 Current Rate Limiting Configuration

#### Existing Protection (Rack::Attack)

```ruby
# Global IP-based throttling
throttle('req/ip', limit: 300, period: 5.minutes, &:ip)
# 300 requests per 5 minutes = 60 req/min per IP

# Login attempt protection
throttle('logins/ip', limit: 5, period: 20.seconds)
throttle('logins/email', limit: 5, period: 20.seconds)
# 5 login attempts per 20 seconds per IP/email

# Fail2Ban for malicious requests
blocklist('fail2ban/php-files') # Block .php file requests
blocklist('fail2ban pentesters') # Block common attack patterns
```

#### ✅ Good Practices
- Redis-backed cache for distributed rate limiting
- Safelist for monitoring services
- Progressive banning (Fail2Ban pattern)
- Custom 503 response to confuse attackers

#### 🔴 Missing API-Specific Limits

**Current Problem:**
```ruby
# Same 300 req/5min limit applies to:
# - Unauthenticated web browsing
# - Authenticated API calls
# - Bulk data export operations
# - Real-time polling requests
```

**Needed:**
```ruby
# Different limits for different contexts
throttle('api/authenticated', limit: 1000, period: 1.hour)
throttle('api/unauthenticated', limit: 100, period: 1.hour)
throttle('api/bulk_operations', limit: 10, period: 1.hour)
throttle('api/per_user', limit: 500, period: 1.hour)
throttle('api/per_application', limit: 5000, period: 1.hour)
```

### 1.3 CORS Configuration

#### Current Setup
```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch('ALLOWED_ORIGINS', '*')
    
    resource "#{BetterTogether.route_scope_path}/api/*",
             headers: %w[Authorization],
             expose: %w[Authorization],
             methods: %i[get post put patch delete options head]
  end
end
```

#### 🔴 Security Issues

1. **Default wildcard origin in development**
```ruby
ALLOWED_ORIGINS='*'  # Accepts requests from any domain
```

**Risk:** CORS bypass, CSRF attacks via API  
**Fix:** Require explicit origin whitelist in production

2. **Limited exposed headers**
```ruby
expose: %w[Authorization]  # Only Authorization header
```

**Missing:** Rate limit headers, pagination headers  
**Needed:** `X-RateLimit-*`, `Link`, `X-Total-Count`

### 1.4 Security Headers

#### Missing Critical Headers
- ✅ CSRF protection (disabled for JSON)
- ❌ No Content-Security-Policy headers
- ❌ No X-Frame-Options for API responses
- ❌ No rate limit information headers

---

## 2. Performance Analysis

### 2.1 Current Performance Characteristics

#### Database Query Patterns
```ruby
# JSONAPI::Resources automatic includes
# Warning messages indicate N+1 potential:
Performance issue detected: `PersonResource.records` 
returned non-normalized results in `find_fragments`
```

**Issues:**
- Automatic eager loading not optimized
- Polymorphic associations cause multiple queries
- No query result caching

#### Response Time Data (from test output)
```
Top 5 slowest examples (7.58 seconds, 9.3% of total time):
  Roles create: 2.62 seconds
  Communities update: 1.33 seconds
  Sessions create: 1.27 seconds
  Communities delete: 1.18 seconds
  People create: 1.17 seconds
```

**Analysis:**
- Write operations (POST/PUT/DELETE) are slow
- Role operations particularly expensive
- No query optimization or caching

### 2.2 Missing Performance Optimizations

1. **No HTTP Caching**
   - No ETag support
   - No Last-Modified headers
   - No conditional GET (304 Not Modified)

2. **No Response Compression**
   - Large JSONAPI responses not gzipped
   - Included relationships multiply payload size

3. **No Database Query Caching**
   - Repeated Pundit scope queries
   - Policy checks not memoized
   - No Redis query cache

4. **No CDN Integration**
   - Public resources not cached
   - No Cache-Control headers

---

## 3. Doorkeeper OAuth2 Implementation Plan

### 3.1 Why OAuth2 + Doorkeeper?

#### Current Problem
```
Mobile App (wants API access)
     ↓
     Requires user email/password
     ↓
     Gets JWT token tied to user session
     ↓
     No way to:
     - Limit app permissions (scopes)
     - Revoke app access without affecting user
     - Track which app made which request
     - Rate limit per-application
```

#### OAuth2 Solution
```
Mobile App/Partner Service
     ↓
     Registers as OAuth application
     ↓
     User authorizes specific scopes (read_profile, write_posts)
     ↓
     App gets access token + refresh token
     ↓
     Rate limits per-application
     Can revoke app without user logout
     Audit trail of app actions
```

### 3.2 Doorkeeper Features

**What Doorkeeper Provides:**
- ✅ OAuth 2.0 server implementation
- ✅ Application registration & management
- ✅ Authorization code flow (user consent)
- ✅ Client credentials flow (server-to-server)
- ✅ Token scopes and permissions
- ✅ Token refresh mechanism
- ✅ Access token revocation
- ✅ Application-level rate limiting keys

### 3.3 Proposed Architecture

#### Dual Authentication Strategy
```ruby
# User-based (current JWT for browser/PWA)
POST /api/auth/sign-in
→ JWT token for user session
→ Short-lived, tied to user

# Application-based (new OAuth2 for apps)
POST /oauth/token
→ OAuth access token
→ Scoped permissions
→ Refresh token for renewal
→ Tied to application + user consent
```

#### Token Types Comparison

| Feature | Current JWT | OAuth2 Access Token |
|---------|-------------|---------------------|
| Lifespan | Indefinite | Configurable (2hr default) |
| Refresh | No | Yes (refresh token) |
| Scopes | No | Yes (granular permissions) |
| Revocation | Denylist | Per-app revocation |
| Rate Limits | Per-IP/user | Per-application |
| Audit Trail | Limited | Full app tracking |
| Third-party | No | Yes |

### 3.4 Implementation Phases

#### Phase 1: Install & Configure Doorkeeper (Week 1)

**1. Add Gem**
```ruby
# Gemfile
gem 'doorkeeper', '~> 5.7'
gem 'doorkeeper-jwt', '~> 0.4'  # For JWT-based tokens
```

**2. Install & Generate**
```bash
bin/dc-run bundle install
bin/dc-run rails generate doorkeeper:install
bin/dc-run rails generate doorkeeper:migration
bin/dc-run rails db:migrate
```

**3. Configure Doorkeeper**
```ruby
# config/initializers/doorkeeper.rb
Doorkeeper.configure do
  # Use ActiveRecord ORM
  orm :active_record

  # Resource owner authentication
  resource_owner_authenticator do
    current_user || warden.authenticate!(scope: :user)
  end

  # Resource owner from access token
  resource_owner_from_credentials do |routes|
    user = User.find_for_database_authentication(email: params[:username])
    if user&.valid_password?(params[:password])
      user
    end
  end

  # Access token expiration
  access_token_expires_in 2.hours
  
  # Refresh token expiration
  use_refresh_token
  
  # Grant flows
  grant_flows %w[authorization_code client_credentials]
  
  # Scopes
  default_scopes :public
  optional_scopes :read_profile, :write_profile,
                  :read_communities, :write_communities,
                  :read_events, :write_events,
                  :admin
end
```

**4. Define Token Scopes**
```ruby
# config/initializers/doorkeeper_scopes.rb
module BetterTogether
  module OAuth
    SCOPES = {
      # Public read access (default)
      public: 'Access public resources',
      
      # Profile scopes
      read_profile: 'Read your profile information',
      write_profile: 'Update your profile information',
      
      # Community scopes
      read_communities: 'View communities you belong to',
      write_communities: 'Create and manage communities',
      
      # Event scopes
      read_events: 'View events you\'re invited to',
      write_events: 'Create and manage events',
      
      # Message scopes
      read_messages: 'Read your messages',
      write_messages: 'Send messages',
      
      # Admin scopes (platform managers only)
      admin: 'Full platform administration access'
    }.freeze
  end
end
```

#### Phase 2: Application Management UI (Week 1)

**5. Create Application Model Extensions**
```ruby
# app/models/better_together/oauth_application.rb
module BetterTogether
  class OauthApplication < Doorkeeper::Application
    belongs_to :owner, polymorphic: true, optional: true
    
    # Audit trail
    has_many :access_tokens,
             class_name: 'Doorkeeper::AccessToken',
             foreign_key: :application_id
    
    # Scopes validation
    validates :scopes, presence: true
    
    # Application types
    enum application_type: {
      web: 'web',
      mobile: 'mobile',
      service: 'service'
    }
    
    # Rate limiting tier
    enum rate_limit_tier: {
      free: 'free',           # 100 req/hour
      basic: 'basic',         # 1,000 req/hour  
      premium: 'premium',     # 10,000 req/hour
      enterprise: 'enterprise' # 100,000 req/hour
    }
  end
end
```

**6. Application Management Controller**
```ruby
# app/controllers/better_together/oauth/applications_controller.rb
module BetterTogether
  module Oauth
    class ApplicationsController < ApplicationController
      before_action :authenticate_user!
      
      def index
        @applications = current_user.oauth_applications
      end
      
      def new
        @application = current_user.oauth_applications.build
      end
      
      def create
        @application = current_user.oauth_applications.build(application_params)
        
        if @application.save
          flash[:success] = 'Application created successfully'
          redirect_to oauth_application_path(@application)
        else
          render :new
        end
      end
      
      def show
        @application = current_user.oauth_applications.find(params[:id])
      end
      
      def destroy
        @application = current_user.oauth_applications.find(params[:id])
        @application.destroy
        redirect_to oauth_applications_path
      end
      
      private
      
      def application_params
        params.require(:oauth_application).permit(
          :name, :redirect_uri, :scopes, :application_type
        )
      end
    end
  end
end
```

#### Phase 3: API Authentication Integration (Week 2)

**7. Add Doorkeeper to API Controllers**
```ruby
# app/controllers/better_together/api/application_controller.rb
module BetterTogether
  module Api
    class ApplicationController < ::JSONAPI::ResourceController
      include Pundit::Authorization
      
      # Support both JWT and OAuth2
      before_action :authenticate_request!
      
      private
      
      def authenticate_request!
        # Try OAuth2 first
        if doorkeeper_token
          authenticate_with_oauth2!
        # Fall back to JWT
        elsif jwt_token_present?
          authenticate_user!
        else
          render_unauthorized
        end
      end
      
      def authenticate_with_oauth2!
        doorkeeper_authorize!
        @current_user = User.find(doorkeeper_token.resource_owner_id)
      end
      
      def jwt_token_present?
        request.headers['Authorization']&.start_with?('Bearer ')
      end
      
      def current_oauth_application
        doorkeeper_token&.application
      end
      
      def current_token_scopes
        doorkeeper_token&.scopes || []
      end
      
      def render_unauthorized
        render json: { error: 'Unauthorized' }, status: :unauthorized
      end
    end
  end
end
```

**8. Scope-Based Authorization**
```ruby
# app/controllers/concerns/better_together/oauth_authorization.rb
module BetterTogether
  module OauthAuthorization
    extend ActiveSupport::Concern
    
    included do
      before_action :verify_oauth_scopes
    end
    
    private
    
    def verify_oauth_scopes
      return unless doorkeeper_token
      
      required_scopes = self.class.required_scopes_for_action(action_name)
      return if required_scopes.empty?
      
      unless doorkeeper_token.acceptable?(required_scopes)
        render json: { 
          error: 'Insufficient scope',
          required: required_scopes,
          provided: doorkeeper_token.scopes.to_a
        }, status: :forbidden
      end
    end
    
    class_methods do
      def require_oauth_scopes(*scopes, only: nil, except: nil)
        @required_oauth_scopes ||= {}
        actions = Array(only || instance_methods(false))
        actions -= Array(except)
        
        actions.each do |action|
          @required_oauth_scopes[action.to_s] = scopes
        end
      end
      
      def required_scopes_for_action(action)
        @required_oauth_scopes&.dig(action.to_s) || []
      end
    end
  end
end
```

**9. Apply Scopes to Controllers**
```ruby
# app/controllers/better_together/api/v1/people_controller.rb
module BetterTogether
  module Api
    module V1
      class PeopleController < ApplicationController
        include OauthAuthorization
        
        # Public endpoints (no scope required)
        skip_before_action :verify_oauth_scopes, only: [:index, :show]
        
        # Profile read access
        require_oauth_scopes :read_profile, only: [:me]
        
        # Profile write access
        require_oauth_scopes :write_profile, only: [:update, :destroy]
      end
    end
  end
end
```

#### Phase 4: Rate Limiting Enhancement (Week 2)

**10. OAuth-Aware Rate Limiting**
```ruby
# config/initializers/rack_attack.rb
Rack::Attack.throttle('api/by_application', limit: :app_rate_limit, period: 1.hour) do |req|
  if req.path.start_with?('/api/') && (app_id = req.env['doorkeeper.token']&.application_id)
    "app:#{app_id}"
  end
end

Rack::Attack.throttle('api/by_user', limit: 500, period: 1.hour) do |req|
  if req.path.start_with?('/api/') && (user_id = req.env['doorkeeper.token']&.resource_owner_id)
    "user:#{user_id}"
  end
end

# Dynamic rate limits based on application tier
def app_rate_limit(req)
  token = req.env['doorkeeper.token']
  return 100 unless token
  
  application = Doorkeeper::Application.find_by(id: token.application_id)
  return 100 unless application
  
  case application.rate_limit_tier
  when 'enterprise' then 100_000
  when 'premium' then 10_000
  when 'basic' then 1_000
  else 100
  end
end
```

**11. Rate Limit Response Headers**
```ruby
# config/initializers/rack_attack.rb
Rack::Attack.throttled_responder = lambda do |env|
  match_data = env['rack.attack.match_data']
  now = Time.now.to_i
  
  headers = {
    'Content-Type' => 'application/json',
    'X-RateLimit-Limit' => match_data[:limit].to_s,
    'X-RateLimit-Remaining' => '0',
    'X-RateLimit-Reset' => (now + match_data[:period]).to_s,
    'Retry-After' => match_data[:period].to_s
  }
  
  [429, headers, [{
    error: 'Rate limit exceeded',
    retry_after: match_data[:period]
  }.to_json]]
end
```

#### Phase 5: Testing & Documentation (Week 3)

**12. RSpec Tests for OAuth**
```ruby
# spec/requests/better_together/api/oauth_authentication_spec.rb
RSpec.describe 'OAuth2 Authentication' do
  let(:user) { create(:user) }
  let(:application) { create(:oauth_application, owner: user) }
  
  describe 'Client Credentials Flow' do
    it 'issues access token for valid client credentials' do
      post '/oauth/token',
           params: {
             grant_type: 'client_credentials',
             client_id: application.uid,
             client_secret: application.secret
           }
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['access_token']).to be_present
      expect(json['token_type']).to eq('Bearer')
    end
  end
  
  describe 'Scoped Access' do
    let(:token) do
      create(:access_token, 
             application: application,
             resource_owner_id: user.id,
             scopes: 'read_profile')
    end
    
    it 'allows access to endpoints within scope' do
      get '/api/v1/people/me',
          headers: { 'Authorization' => "Bearer #{token.token}" }
      
      expect(response).to have_http_status(:ok)
    end
    
    it 'denies access to endpoints outside scope' do
      put "/api/v1/people/#{user.person.id}",
          params: { data: { attributes: { name: 'New Name' } } },
          headers: { 'Authorization' => "Bearer #{token.token}" }
      
      expect(response).to have_http_status(:forbidden)
    end
  end
end
```

---

## 4. Enhanced Security Recommendations

### 4.1 Token Security

#### Add JWT Token Expiration
```ruby
# config/initializers/devise.rb
Devise.setup do |config|
  config.jwt do |jwt|
    jwt.secret = Rails.application.credentials.devise_jwt_secret_key!
    jwt.dispatch_requests = [
      ['POST', %r{^/api/auth/sign-in$}]
    ]
    jwt.revocation_requests = [
      ['DELETE', %r{^/api/auth/sign-out$}]
    ]
    jwt.expiration_time = 2.hours.to_i  # Add expiration
  end
end
```

#### Implement Token Refresh Endpoint
```ruby
# app/controllers/better_together/api/auth/tokens_controller.rb
module BetterTogether
  module Api
    module Auth
      class TokensController < ApplicationController
        skip_before_action :authenticate_user!, only: :refresh
        
        def refresh
          old_token = request.headers['Authorization']&.delete_prefix('Bearer ')
          
          if valid_refresh_token?(old_token)
            new_token = generate_new_token(old_token)
            response.headers['Authorization'] = "Bearer #{new_token}"
            render json: { message: 'Token refreshed' }, status: :ok
          else
            render json: { error: 'Invalid refresh token' }, status: :unauthorized
          end
        end
        
        private
        
        def valid_refresh_token?(token)
          # Implement token validation logic
        end
        
        def generate_new_token(old_token)
          # Generate new token with extended expiration
        end
      end
    end
  end
end
```

### 4.2 CORS Hardening

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Production: Require explicit whitelist
    origins ENV.fetch('ALLOWED_ORIGINS').split(',')
    
    resource "#{BetterTogether.route_scope_path}/api/*",
             headers: %w[
               Authorization
               Content-Type
               Accept
               X-Requested-With
             ],
             expose: %w[
               Authorization
               X-RateLimit-Limit
               X-RateLimit-Remaining
               X-RateLimit-Reset
               Link
               X-Total-Count
             ],
             methods: %i[get post put patch delete options head],
             credentials: true,
             max_age: 3600  # Preflight cache time
  end
  
  # Reject all other origins
  allow do
    origins '*'
    resource '*', 
             headers: [],
             methods: [:options],
             credentials: false
  end
end
```

### 4.3 Security Headers

```ruby
# config/initializers/security_headers.rb
Rails.application.config.action_dispatch.default_headers.merge!({
  'X-Frame-Options' => 'DENY',
  'X-Content-Type-Options' => 'nosniff',
  'X-XSS-Protection' => '1; mode=block',
  'Referrer-Policy' => 'strict-origin-when-cross-origin'
})

# Add to API responses
module BetterTogether
  module Api
    class ApplicationController < ::JSONAPI::ResourceController
      after_action :set_api_security_headers
      
      private
      
      def set_api_security_headers
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['Cache-Control'] = 'no-store'
        response.headers['Pragma'] = 'no-cache'
      end
    end
  end
end
```

---

## 5. Performance Optimizations

### 5.1 HTTP Caching

```ruby
# app/controllers/better_together/api/v1/base_controller.rb
class BaseController < ApplicationController
  # ETags for conditional GET
  def show
    record = find_resource
    
    if stale?(record, public: record.privacy_public?)
      respond_with_resource(record)
    end
  end
  
  # Collection ETags
  def index
    collection = find_collection
    
    if stale?(etag: collection, public: false)
      respond_with_collection(collection)
    end
  end
end
```

### 5.2 Database Query Optimization

```ruby
# app/resources/better_together/api/v1/person_resource.rb
class PersonResource < JSONAPI::Resource
  # Optimize includes
  def self.records(options = {})
    context = options[:context]
    
    base_query = super(options)
      .includes(:identification_identity, :created_by_agent)
      .select('people.*, identities.name as identity_name')
      .joins(:identification_identity)
    
    # Apply caching for public records
    if context[:cache_enabled]
      base_query.cache_key_with_version
    end
    
    base_query
  end
end
```

### 5.3 Response Compression

```ruby
# config/initializers/middleware.rb
Rails.application.config.middleware.use Rack::Deflater
```

### 5.4 Redis Caching

```ruby
# app/controllers/concerns/better_together/api_caching.rb
module BetterTogether
  module ApiCaching
    extend ActiveSupport::Concern
    
    included do
      around_action :cache_api_response, if: :cacheable_action?
    end
    
    private
    
    def cache_api_response
      cache_key = api_cache_key
      
      cached_response = Rails.cache.read(cache_key)
      
      if cached_response
        render json: cached_response
      else
        yield
        Rails.cache.write(cache_key, response.body, expires_in: 5.minutes)
      end
    end
    
    def api_cache_key
      [
        controller_name,
        action_name,
        params.to_query,
        current_user&.cache_key_with_version
      ].join('/')
    end
    
    def cacheable_action?
      request.get? && !doorkeeper_token&.scopes&.include?('admin')
    end
  end
end
```

---

## 6. Implementation Checklist

### Week 1: OAuth2 Setup
- [ ] Add Doorkeeper gem
- [ ] Run migrations
- [ ] Configure scopes
- [ ] Create OAuth application model extensions
- [ ] Build application management UI
- [ ] Write OAuth integration tests

### Week 2: API Integration
- [ ] Update API controllers for dual auth
- [ ] Implement scope-based authorization
- [ ] Add OAuth-aware rate limiting
- [ ] Add rate limit response headers
- [ ] Update API documentation

### Week 3: Security & Performance
- [ ] Implement JWT token expiration
- [ ] Add token refresh endpoint
- [ ] Harden CORS configuration
- [ ] Add security headers
- [ ] Implement HTTP caching
- [ ] Add response compression
- [ ] Optimize database queries

### Week 4: Testing & Documentation
- [ ] Comprehensive OAuth test suite
- [ ] Performance benchmarking
- [ ] Security audit with Brakeman
- [ ] Update Swagger documentation
- [ ] Developer guide for API consumers
- [ ] Migration guide for existing integrations

---

## 7. Migration Strategy

### Backward Compatibility

**Goal:** Maintain existing JWT authentication while adding OAuth2

```ruby
# Both authentication methods work simultaneously
# Existing apps continue using JWT
POST /api/auth/sign-in → JWT token (existing)

# New apps use OAuth2
POST /oauth/token → OAuth access token (new)
```

### Deprecation Timeline

**Phase 1 (Months 1-3):** Dual support
- JWT and OAuth2 both work
- Encourage new apps to use OAuth2
- Document migration path

**Phase 2 (Months 4-6):** Migration period  
- Send deprecation warnings to JWT-only clients
- Provide migration support
- Monitor adoption rates

**Phase 3 (Month 7+):** OAuth2 only
- Disable JWT for API access (web sessions continue)
- OAuth2 required for all API consumers

---

## 8. Success Metrics

### Security Metrics
- [ ] 100% of third-party apps use OAuth2
- [ ] Zero exposed JWT tokens in logs
- [ ] Zero CORS violations in production
- [ ] Average token refresh latency < 100ms

### Performance Metrics
- [ ] API response time p95 < 500ms
- [ ] Cache hit rate > 80% for public endpoints
- [ ] Rate limit headers present on 100% of responses
- [ ] Zero N+1 queries in API endpoints

### Adoption Metrics
- [ ] 10+ registered OAuth applications
- [ ] 100+ active OAuth access tokens
- [ ] 50% reduction in API support tickets
- [ ] 90% developer satisfaction score

---

## 9. Next Steps

1. **Review and Approve Plan** - Stakeholder sign-off
2. **Create Implementation Tickets** - Break into actionable tasks
3. **Set Up Development Environment** - Test Doorkeeper locally
4. **Begin Phase 1** - Install and configure Doorkeeper
5. **Continuous Testing** - Security and performance tests throughout

---

**Document Owner:** Better Together Engineering Team  
**Last Updated:** January 29, 2026  
**Next Review:** February 15, 2026
