# API Documentation Assessment - Rswag/Swagger Implementation Status

**Assessment Date:** January 28, 2026  
**Branch:** Current development branch  
**Assessed By:** GitHub Copilot

## Executive Summary

The Better Together Community Engine has **minimal Swagger/OpenAPI documentation** compared to the extensive API endpoints currently implemented. The project uses rswag for API documentation but has not yet generated comprehensive Swagger specs for most endpoints.

### Current State
- ✅ **Rswag installed and configured** (`spec/swagger_helper.rb`)
- ⚠️ **Minimal documentation coverage** (4 basic POST endpoints documented)
- ❌ **No rswag integration specs** - specs exist but don't use rswag's path DSL
- ❌ **Auth endpoints not documented** in Swagger
- ❌ **Relationship routes not documented**
- ❌ **GET endpoints not documented**

### Documentation Coverage

| Category | Implemented | Documented | Coverage |
|----------|------------|------------|----------|
| Auth Endpoints | 9 | 0 | 0% |
| V1 Resource Endpoints | 40+ | 4 | ~10% |
| Relationship Endpoints | 20+ | 0 | 0% |
| **Total** | **69+** | **4** | **~6%** |

---

## Implemented vs. Documented Endpoints

### 1. Authentication Endpoints (0% documented)

#### Implemented Routes (9 endpoints)
- `POST /api/auth/sign-in` - User login with JWT
- `DELETE /api/auth/sign-out` - User logout
- `POST /api/auth/sign-up` - User registration
- `PUT/PATCH /api/auth/sign-up` - Update registration
- `DELETE /api/auth/sign-up` - Cancel registration
- `POST /api/auth/password` - Request password reset
- `PUT/PATCH /api/auth/password` - Update password
- `GET /api/auth/confirmation` - Email confirmation
- `POST /api/auth/confirmation` - Resend confirmation

#### Test Coverage
✅ Comprehensive RSpec tests exist:
- `spec/requests/better_together/api/auth/sessions_api_spec.rb` (169 lines)
- `spec/requests/better_together/api/auth/registrations_api_spec.rb` (188 lines)
- `spec/requests/better_together/api/auth/passwords_spec.rb`
- `spec/requests/better_together/api/auth/confirmations_spec.rb`
- `spec/requests/better_together/api/security_spec.rb`

#### Swagger Documentation
❌ **None** - No rswag integration specs exist for auth endpoints

---

### 2. API V1 Resource Endpoints

#### People Resource (5 documented, 20+ implemented)

**Documented in `swagger/v1/swagger.yaml`:**
```yaml
"/bt/api/v1/people":
  post:
    summary: Create a person
    responses:
      '201': description: person created
      '422': description: invalid request
```

**Actually Implemented Routes:**
1. `GET /:locale/api/v1/people/me` - Get current user's person
2. `GET /:locale/api/v1/people` - List all people
3. `POST /:locale/api/v1/people` - Create person ✅ **Documented**
4. `GET /:locale/api/v1/people/:id` - Show person
5. `PATCH/PUT /:locale/api/v1/people/:id` - Update person
6. `DELETE /:locale/api/v1/people/:id` - Delete person

**Relationship Routes (NOT documented):**
- `GET/PUT/PATCH/DELETE /:locale/api/v1/people/:person_id/relationships/user`
- `GET /:locale/api/v1/people/:person_id/user` - Related user resource
- `GET/POST/PUT/PATCH/DELETE /:locale/api/v1/people/:person_id/relationships/communities`
- `GET /:locale/api/v1/people/:person_id/communities` - Related communities
- `GET/POST/PUT/PATCH/DELETE /:locale/api/v1/people/:person_id/relationships/person_community_memberships`
- `GET /:locale/api/v1/people/:person_id/person_community_memberships` - Related memberships

**Test Coverage:**
✅ `spec/requests/better_together/api/v1/people_spec.rb`  
✅ `spec/requests/better_together/api/v1/people_api_spec.rb`

---

#### Communities Resource (1 documented, 20+ implemented)

**Documented in `swagger/v1/swagger.yaml`:**
```yaml
"/bt/api/v1/communities":
  post:
    summary: Create a community
    responses:
      '201': description: community created
      '422': description: invalid request
```

**Actually Implemented Routes:**
1. `GET /:locale/api/v1/communities` - List communities
2. `POST /:locale/api/v1/communities` - Create community ✅ **Documented**
3. `GET /:locale/api/v1/communities/:id` - Show community
4. `PATCH/PUT /:locale/api/v1/communities/:id` - Update community
5. `DELETE /:locale/api/v1/communities/:id` - Delete community

**Relationship Routes (NOT documented):**
- `GET/PUT/PATCH/DELETE /:locale/api/v1/communities/:id/relationships/creator`
- `GET /:locale/api/v1/communities/:id/creator` - Related creator
- `GET/POST/PUT/PATCH/DELETE /:locale/api/v1/communities/:id/relationships/members`
- `GET /:locale/api/v1/communities/:id/members` - Related members
- `GET/POST/PUT/PATCH/DELETE /:locale/api/v1/communities/:id/relationships/person_community_memberships`
- `GET /:locale/api/v1/communities/:id/person_community_memberships` - Related memberships

**Test Coverage:**
✅ `spec/requests/better_together/api/v1/communities_spec.rb`  
✅ `spec/requests/better_together/api/v1/communities_api_spec.rb`

---

#### Community Memberships Resource (1 documented, 15+ implemented)

**Documented in `swagger/v1/swagger.yaml`:**
```yaml
"/bt/api/v1/community_memberships":
  post:
    summary: Create a community_membership
    responses:
      '201': description: community_membership created
      '500': description: invalid request  # ⚠️ Should be 422
```

**Actually Implemented Routes:**
1. `GET /:locale/api/v1/person_community_memberships` - List memberships
2. `POST /:locale/api/v1/person_community_memberships` - Create membership ✅ **Documented** (wrong path)
3. `GET /:locale/api/v1/person_community_memberships/:id` - Show membership
4. `PATCH/PUT /:locale/api/v1/person_community_memberships/:id` - Update membership
5. `DELETE /:locale/api/v1/person_community_memberships/:id` - Delete membership

**⚠️ Documentation Issue:** Documented path is `/community_memberships` but actual path is `/person_community_memberships`

**Relationship Routes (NOT documented):**
- `GET/PUT/PATCH/DELETE /:locale/api/v1/person_community_memberships/:id/relationships/member`
- `GET /:locale/api/v1/person_community_memberships/:id/member` - Related member
- `GET/PUT/PATCH/DELETE /:locale/api/v1/person_community_memberships/:id/relationships/joinable`

**Test Coverage:**
✅ `spec/requests/better_together/api/v1/community_memberships_api_spec.rb`  
✅ `spec/requests/better_together/api/v1/community_membership_spec.rb`

---

#### Roles Resource (1 documented, 6 implemented)

**Documented in `swagger/v1/swagger.yaml`:**
```yaml
"/bt/api/v1/roles":
  post:
    summary: Create a role
    responses:
      '201': description: role created
      '422': description: invalid request
```

**Actually Implemented Routes:**
1. `GET /:locale/api/v1/roles` - List roles (read-only)
2. `POST /:locale/api/v1/roles` - Create role ✅ **Documented** (⚠️ may not be allowed)
3. `GET /:locale/api/v1/roles/:id` - Show role
4. `PATCH/PUT /:locale/api/v1/roles/:id` - Update role
5. `DELETE /:locale/api/v1/roles/:id` - Delete role

**⚠️ Documentation Issue:** Roles are marked as "read-only" in routes but Swagger documents POST endpoint

**Test Coverage:**
✅ `spec/requests/better_together/api/v1/roles_spec.rb`  
✅ `spec/requests/better_together/api/v1/roles_api_spec.rb`

---

## Current Swagger Configuration

### `spec/swagger_helper.rb`

```ruby
config.swagger_root = File.join('../../', BetterTogether::Engine.root.to_s, '/swagger')

config.swagger_docs = {
  'v1/swagger.yaml' => {
    openapi: '3.0.1',
    info: {
      title: 'Community Engine API',
      version: 'v1'
    },
    paths: {},
    servers: [
      {
        url: 'https://{defaultHost}',
        variables: {
          defaultHost: {
            default: 'api.bebettertogether.ca'
          }
        }
      }
    ]
  }
}

config.swagger_format = :yaml
```

### Current `swagger/v1/swagger.yaml`

Only contains **4 basic POST endpoint descriptions**:
- People POST (minimal)
- Communities POST (minimal)
- Community Memberships POST (path mismatch)
- Roles POST (minimal)

**Missing from documentation:**
- GET endpoints for all resources
- PATCH/PUT/DELETE endpoints
- Authentication endpoints
- Relationship endpoints (JSONAPI format)
- Request body schemas (only type: object with name property)
- Response schemas (empty content blocks)
- Authentication/Authorization headers
- Error response formats
- Pagination details
- Filter/sort parameters

---

## Testing Infrastructure

### Existing Test Files (NOT using rswag)

All current API specs use standard RSpec request specs, not rswag integration specs:

```ruby
# Current pattern (standard RSpec)
RSpec.describe 'BetterTogether::Api::Auth::Registrations', :no_auth do
  describe 'POST /api/auth/sign-up' do
    let(:url) { '/api/auth/sign-up' }
    
    it 'creates a new user' do
      post url, params: valid_params, as: :json
      expect(response).to have_http_status(:created)
    end
  end
end
```

**Should be (rswag pattern):**
```ruby
# Rswag pattern for Swagger generation
RSpec.describe 'API Auth - Registrations', swagger_doc: 'v1/swagger.yaml' do
  path '/api/auth/sign-up' do
    post 'Register a new user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, format: :email },
              password: { type: :string, format: :password },
              password_confirmation: { type: :string, format: :password }
            },
            required: %w[email password password_confirmation]
          }
        }
      }
      
      response '201', 'user created' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     id: { type: :string },
                     attributes: { type: :object }
                   }
                 }
               }
        
        let(:user) { { user: { email: 'test@example.com', ... } } }
        run_test!
      end
    end
  end
end
```

---

## Issues Identified

### Critical Issues

1. **No rswag integration specs** - All tests use standard RSpec, missing Swagger generation
2. **Incomplete documentation** - Only 4 POST endpoints of 69+ total endpoints documented
3. **Path mismatches** - `/community_memberships` in docs vs `/person_community_memberships` in code
4. **No authentication documentation** - 9 auth endpoints completely undocumented
5. **No relationship endpoints** - JSONAPI relationship routes (20+) not documented

### Documentation Quality Issues

6. **Empty response schemas** - `content: {}` instead of proper JSONAPI response schemas
7. **Generic error responses** - "invalid request" instead of detailed validation errors
8. **Missing request schemas** - Only generic `type: object` with minimal properties
9. **No authentication headers** - JWT Bearer token handling not documented
10. **Inconsistent error codes** - Community Memberships shows 500 instead of 422

### Missing Features Documentation

11. **No GET endpoints** - List/show operations not documented
12. **No UPDATE/DELETE** - PATCH/PUT/DELETE operations not documented
13. **No pagination** - JSONAPI pagination not documented
14. **No filtering/sorting** - Query parameters not documented
15. **No included resources** - JSONAPI `include` parameter not documented
16. **No sparse fieldsets** - JSONAPI `fields` parameter not documented

---

## Recommendations

### Immediate Priorities (High Impact)

1. **Convert existing RSpec specs to rswag format** for auth endpoints
   - Start with registrations (highest priority due to current failing tests)
   - Then sessions, passwords, confirmations
   - Use `run_test!` to auto-generate Swagger docs

2. **Document authentication scheme** in Swagger
   ```yaml
   components:
     securitySchemes:
       bearerAuth:
         type: http
         scheme: bearer
         bearerFormat: JWT
   ```

3. **Fix path mismatches** in existing documentation
   - Update `/community_memberships` to `/person_community_memberships`
   - Correct error response codes (500 → 422)

4. **Add proper JSONAPI response schemas**
   ```yaml
   components:
     schemas:
       Person:
         type: object
         properties:
           data:
             type: object
             properties:
               type: { type: string, example: 'people' }
               id: { type: string, format: uuid }
               attributes:
                 type: object
                 properties:
                   name: { type: string }
                   identifier: { type: string }
   ```

### Medium-Term Improvements

5. **Document all CRUD operations** for existing resources
   - GET (index/show)
   - POST (create)
   - PATCH/PUT (update)
   - DELETE (destroy)

6. **Document JSONAPI relationship endpoints**
   - Use proper JSONAPI relationship request/response formats
   - Document `GET/POST/PATCH/DELETE` for relationships
   - Document related resource endpoints

7. **Add query parameter documentation**
   - Pagination (`page[number]`, `page[size]`)
   - Filtering (`filter[field]`)
   - Sorting (`sort`)
   - Sparse fieldsets (`fields[resource]`)
   - Including relationships (`include`)

8. **Document error response formats**
   ```yaml
   responses:
     UnprocessableEntity:
       description: Validation errors
       content:
         application/json:
           schema:
             type: object
             properties:
               errors:
                 type: array
                 items:
                   type: object
                   properties:
                     source: { type: object }
                     detail: { type: string }
   ```

### Long-Term Enhancements

9. **Add API versioning strategy** to documentation
10. **Create comprehensive examples** for each endpoint
11. **Add rate limiting documentation**
12. **Document webhook endpoints** (if applicable)
13. **Create SDKs** based on OpenAPI spec
14. **Set up automated API documentation deployment** (Swagger UI)
15. **Add API changelog** for version tracking

---

## Migration Path: Converting Tests to Rswag

### Step 1: Create Integration Spec Directory
```bash
mkdir -p spec/integration/api/v1
mkdir -p spec/integration/api/auth
```

### Step 2: Convert One Auth Spec (Template)

**Important:** Rswag wraps standard RSpec - you keep ALL your existing assertions!

**Before** (`spec/requests/better_together/api/auth/registrations_api_spec.rb`):
```ruby
RSpec.describe 'BetterTogether::Api::Auth::Registrations', :no_auth do
  describe 'POST /api/auth/sign-up' do
    let(:url) { '/api/auth/sign-up' }
    
    it 'creates a new user' do
      post url, params: valid_params, as: :json
      expect(response).to have_http_status(:created)
    end
  end
end
```

**After** (`spec/integration/api/auth/registrations_spec.rb`):
Rswag DSL + all your existing RSpec assertions!
```ruby
require 'swagger_helper'

RSpec.describe 'API Auth - User Registration', swagger_doc: 'v1/swagger.yaml' do
  path '/api/auth/sign-up' do
    post 'Register a new user account' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      
      parameter name: :registration, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, format: :email, example: 'user@example.com' },
              password: { type: :string, format: :password, minLength: 8 },
              password_confirmation: { type: :string, format: :password },
              person_attributes: {
                type: :object,
                properties: {
                  name: { type: :string, example: 'John Doe' },
                  identifier: { type: :string, example: 'john-doe' },
                  description: { type: :string }
                }
              }
            },
            required: %w[email password password_confirmation]
          },
          privacy_policy_agreement: { type: :string, enum: ['0', '1'] },
          terms_of_service_agreement: { type: :string, enum: ['0', '1'] },
          code_of_conduct_agreement: { type: :string, enum: ['0', '1'] }
        }
      }
      
      response '201', 'User created successfully' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     type: { type: :string, example: 'users' },
                     id: { type: :string, format: :uuid },
                     attributes: {
                       type: :object,
                       properties: {
                         email: { type: :string },
                         confirmed: { type: :boolean }
                       }
                     },
                     relationships: {
                       type: :object,
                       properties: {
                         person: { type: :object }
                       }
                     }
                   }
                 }
               }
        
        let(:registration) do
          {
            user: {
              email: 'newuser@example.com',
              password: 'SecureTest123!@#',
              password_confirmation: 'SecureTest123!@#',
              person_attributes: {
                name: 'Test User',
                identifier: 'test-user'
              }
            },
            privacy_policy_agreement: '1',
            terms_of_service_agreement: '1',
            code_of_conduct_agreement: '1'
          }
        end
        
        run_test! do |response|
          # ALL YOUR EXISTING RSPEC ASSERTIONS WORK HERE!
          data = JSON.parse(response.body)
          expect(data['data']['type']).to eq('users')
          expect(data['data']['attributes']['email']).to eq('newuser@example.com')
          
          # You can add as many assertions as you want
          expect(BetterTogether::User.count).to have_changed.by(1)
          expect(BetterTogether::Person.count).to have_changed.by(1)
          expect(data['data']['attributes']).not_to have_key('password')
        end
      end
      
      response '422', 'Validation errors' do
        schema type: :object,
               properties: {
                 errors: {
                   type: :array,
                   items: { type: :string }
                 }
               }
        
        let(:registration) do
          {
            user: {
              email: 'invalid',
              password: 'short'
            }
          }
        end
        
        run_test!
      end
    end
  end
end
```

### Step 3: Generate Updated Swagger Docs
```bash

---

## FAQ: Rswag Integration

### Can rswag coexist with existing RSpec assertions?

**YES!** Rswag is **built on top of RSpec** and works alongside all your existing assertions:

```ruby
# Rswag spec with FULL RSpec assertion support
response '201', 'user created' do
  schema type: :object  # Swagger schema definition
  
  run_test! do |response|
    # ALL YOUR EXISTING RSPEC ASSERTIONS STILL WORK!
    expect(response).to have_http_status(:created)
    
    json = JSON.parse(response.body)
    expect(json['data']['type']).to eq('users')
    expect(json['data']['attributes']['email']).to be_present
    expect(json['data']['attributes']).not_to have_key('password')
    
    # Database assertions
    expect(BetterTogether::User.count).to eq(1)
    expect(BetterTogether::Person.count).to eq(1)
    
    # Any other RSpec matchers you use
    expect(ActionMailer::Base.deliveries.count).to eq(1)
  end
end
```

### What does rswag add to standard RSpec?

1. **Swagger Documentation Generation** - Automatically builds OpenAPI specs
2. **Request/Response Schemas** - Documents expected formats
3. **Parameter Definitions** - Documents required/optional params
4. **Example Generation** - Creates Swagger UI examples

### What stays the same?

1. **All RSpec assertions** - `expect()`, matchers, custom helpers
2. **Test setup** - `let`, `before`, `after` blocks
3. **Factory usage** - FactoryBot works identically
4. **Helper methods** - All existing spec helpers work
5. **Metadata** - Tags like `:no_auth` still work

### Do I need separate test files?

**No!** You have two options:

**Option A: Single file approach** (Recommended)
- Keep existing spec files
- Add rswag DSL (`path`, `response`, `schema`) around existing assertions
- Get both test coverage AND documentation from one file

**Option B: Separate integration specs**
- Keep existing request specs as-is for detailed testing
- Create minimal integration specs purely for Swagger generation
- Useful if existing specs are very complex

### What about test duplication?

Rswag uses `run_test!` which:
1. Executes the HTTP request
2. Validates response against schema
3. Runs your custom assertions in the block
4. Generates Swagger documentation

So one test = multiple validations + documentation!

### Can I gradually migrate?

**Absolutely!** Recommended approach:

1. **Start with new endpoints** - Use rswag format for any new API endpoints
2. **Convert high-value endpoints** - Start with auth, then core resources
3. **Leave complex tests alone** - If conversion is difficult, keep existing format
4. **Mix both approaches** - Request specs for detailed tests, integration specs for docs

### Example: Hybrid Approach

Keep your detailed request spec:
```ruby
# spec/requests/better_together/api/auth/registrations_api_spec.rb
RSpec.describe 'BetterTogether::Api::Auth::Registrations' do
  # 50+ detailed test cases with complex scenarios
end
```

Add a simpler integration spec for documentation:
```ruby
# spec/integration/api/auth/registrations_spec.rb
require 'swagger_helper'

RSpec.describe 'API Auth - Registrations', swagger_doc: 'v1/swagger.yaml' do
  path '/api/auth/sign-up' do
    post 'Register new user' do
      # Document happy path + major error cases
      # Full test coverage already exists in request spec
    end
  end
end
```

Both specs run in your test suite - one provides coverage, one provides documentation!
bin/dc-run bundle exec rake rswag:specs:swaggerize
```

### Step 4: Verify Generated Documentation
- Check `swagger/v1/swagger.yaml` for new endpoint documentation
- Test Swagger UI (if mounted): visit `/bt/api/docs`

---

## Estimated Effort

| Task | Endpoints | Effort | Priority |
|------|-----------|--------|----------|
| Auth endpoint specs | 9 | 2-3 days | P0 (Critical) |
| People resource specs | 6 + 6 relationships | 2 days | P1 (High) |
| Communities specs | 5 + 6 relationships | 2 days | P1 (High) |
| Memberships specs | 5 + 4 relationships | 1.5 days | P1 (High) |
| Roles specs | 5 | 1 day | P2 (Medium) |
| Schema components | All | 1 day | P1 (High) |
| Error responses | All | 0.5 days | P1 (High) |
| Query parameters | All | 1 day | P2 (Medium) |
| **Total** | **69+** | **~11 days** | |

---

## Success Metrics

### Short Term (1-2 weeks)
- [ ] All 9 auth endpoints fully documented with rswag specs
- [ ] JSONAPI response schemas defined in `components/schemas`
- [ ] Authentication scheme documented (JWT Bearer)
- [ ] Path mismatches corrected
- [ ] Error response formats standardized

### Medium Term (1 month)
- [ ] All CRUD operations documented for 4 main resources
- [ ] All relationship endpoints documented
- [ ] Query parameters documented (pagination, filtering, sorting)
- [ ] Swagger UI accessible and functional
- [ ] Generated docs match actual API behavior 100%

### Long Term (2-3 months)
- [ ] API documentation coverage > 95%
- [ ] Automated Swagger generation in CI/CD pipeline
- [ ] Public API documentation site deployed
- [ ] Client SDKs generated from OpenAPI spec
- [ ] API versioning strategy implemented and documented

---

## Next Steps

1. **Fix immediate test failures** in registration controller (NameError with block parameter)
2. **Create first rswag integration spec** for `/api/auth/sign-up` as template
3. **Convert remaining auth specs** to rswag format
4. **Define JSONAPI schemas** in `components/schemas` section
5. **Set up Swagger UI** mounting for interactive documentation
6. **Establish documentation workflow** - require Swagger updates for new API endpoints

---

## Resources

- **Rswag Documentation:** https://github.com/rswag/rswag
- **OpenAPI 3.0 Spec:** https://swagger.io/specification/
- **JSONAPI Specification:** https://jsonapi.org/
- **Current Swagger File:** `swagger/v1/swagger.yaml`
- **Swagger Helper:** `spec/swagger_helper.rb`
- **Existing API Tests:** `spec/requests/better_together/api/**/*_spec.rb`

---

## Appendix: Complete Endpoint Inventory

### Authentication Endpoints (9 total)

| Method | Path | Controller Action | Documented | Tested |
|--------|------|------------------|------------|--------|
| POST | `/api/auth/sign-in` | sessions#create | ❌ | ✅ |
| DELETE | `/api/auth/sign-out` | sessions#destroy | ❌ | ✅ |
| POST | `/api/auth/sign-up` | registrations#create | ❌ | ✅ |
| PUT/PATCH | `/api/auth/sign-up` | registrations#update | ❌ | ✅ |
| DELETE | `/api/auth/sign-up` | registrations#destroy | ❌ | ✅ |
| POST | `/api/auth/password` | passwords#create | ❌ | ✅ |
| PUT/PATCH | `/api/auth/password` | passwords#update | ❌ | ✅ |
| GET | `/api/auth/confirmation` | confirmations#show | ❌ | ✅ |
| POST | `/api/auth/confirmation` | confirmations#create | ❌ | ✅ |

### V1 Resource Endpoints (40+ total)

#### People (6 + 6 relationships)
| Method | Path | Documented | Tested |
|--------|------|------------|--------|
| GET | `/:locale/api/v1/people/me` | ❌ | ✅ |
| GET | `/:locale/api/v1/people` | ❌ | ✅ |
| POST | `/:locale/api/v1/people` | ⚠️ (minimal) | ✅ |
| GET | `/:locale/api/v1/people/:id` | ❌ | ✅ |
| PATCH/PUT | `/:locale/api/v1/people/:id` | ❌ | ✅ |
| DELETE | `/:locale/api/v1/people/:id` | ❌ | ✅ |
| *Relationships* | *6 relationship endpoints* | ❌ | ❓ |

#### Communities (5 + 6 relationships)
| Method | Path | Documented | Tested |
|--------|------|------------|--------|
| GET | `/:locale/api/v1/communities` | ❌ | ✅ |
| POST | `/:locale/api/v1/communities` | ⚠️ (minimal) | ✅ |
| GET | `/:locale/api/v1/communities/:id` | ❌ | ✅ |
| PATCH/PUT | `/:locale/api/v1/communities/:id` | ❌ | ✅ |
| DELETE | `/:locale/api/v1/communities/:id` | ❌ | ✅ |
| *Relationships* | *6 relationship endpoints* | ❌ | ❓ |

#### Person Community Memberships (5 + 4 relationships)
| Method | Path | Documented | Tested |
|--------|------|------------|--------|
| GET | `/:locale/api/v1/person_community_memberships` | ❌ | ✅ |
| POST | `/:locale/api/v1/person_community_memberships` | ⚠️ (wrong path) | ✅ |
| GET | `/:locale/api/v1/person_community_memberships/:id` | ❌ | ✅ |
| PATCH/PUT | `/:locale/api/v1/person_community_memberships/:id` | ❌ | ✅ |
| DELETE | `/:locale/api/v1/person_community_memberships/:id` | ❌ | ✅ |
| *Relationships* | *4 relationship endpoints* | ❌ | ❓ |

#### Roles (5 read-only)
| Method | Path | Documented | Tested |
|--------|------|------------|--------|
| GET | `/:locale/api/v1/roles` | ❌ | ✅ |
| POST | `/:locale/api/v1/roles` | ⚠️ (shouldn't exist?) | ✅ |
| GET | `/:locale/api/v1/roles/:id` | ❌ | ✅ |
| PATCH/PUT | `/:locale/api/v1/roles/:id` | ❌ | ✅ |
| DELETE | `/:locale/api/v1/roles/:id` | ❌ | ✅ |

---

**Legend:**
- ✅ = Complete/Exists
- ⚠️ = Partial/Issues
- ❌ = Missing/Not Done
- ❓ = Unknown/Needs Investigation

**End of Assessment**
