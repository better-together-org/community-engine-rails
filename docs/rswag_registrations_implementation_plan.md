# Rswag Implementation Plan: Registrations API

**Date:** January 28, 2026  
**Endpoint:** `POST /api/auth/sign-up`  
**Controller:** `BetterTogether::Api::Auth::RegistrationsController`  
**Existing Spec:** `spec/requests/better_together/api/auth/registrations_api_spec.rb`

---

## Current State Analysis

### Existing Test Coverage

The current spec has **excellent coverage** with 15 test cases across 6 contexts:

#### ✅ Valid Parameters Context (6 tests)
1. Creates a new user (database change assertion)
2. Creates an associated person (database change assertion)
3. Returns created status (HTTP status)
4. Returns JSONAPI-formatted user data (response structure)
5. Does not expose password fields (security)
6. Sends a confirmation email (side effect)

#### ✅ Error Handling Contexts (9 tests)
7. Missing email - returns 422
8. Missing email - doesn't create user
9. Invalid email format - returns 422
10. Duplicate email - returns 422
11. Duplicate email - doesn't create user
12. Weak password - returns 422
13. Mismatched passwords - returns 422

### Current Test Failures

**13 failures detected** in terminal output - all related to `NameError` in controller:

```
JSON::ParserError: unexpected token 'NameError' at line 1 column 1
```

**Root Cause:** The controller has a `&block` parameter issue that needs fixing first.

---

## Implementation Strategy: Keep Both Specs

**Recommendation:** Create a **companion rswag spec** alongside the existing detailed spec.

### Why Keep Both?

1. **Existing spec is excellent** - comprehensive, well-organized, detailed assertions
2. **Different purposes:**
   - **Existing spec** → Thorough testing, edge cases, database changes, email delivery
   - **Rswag spec** → API documentation, request/response schemas, consumer examples
3. **No duplication** - Rswag focuses on happy path + major error cases for docs
4. **Maintain test stability** - Existing spec already passing (once controller fixed)

---

## Rswag Integration Spec Plan

### File Location
```
spec/integration/api/auth/registrations_spec.rb
```

### Coverage Strategy

The rswag spec will document **5 key scenarios** for API consumers:

1. **Successful registration (201)** - Happy path with full request/response
2. **Missing required field (422)** - Email validation error
3. **Invalid email format (422)** - Email format validation
4. **Duplicate email (422)** - Uniqueness constraint
5. **Weak password (422)** - Password strength validation

This gives API consumers examples of:
- ✅ How to successfully register
- ✅ Common validation errors they'll encounter
- ✅ Expected response structures

### What Stays in Existing Spec?

Detailed test cases that don't need Swagger documentation:
- Database change assertions (creating person record)
- Email delivery verification (ActionMailer side effects)
- Password exposure security checks (internal security)
- "Doesn't create user" negative assertions
- Mismatched password scenario (already covered by validation errors)

---

## Rswag Spec Implementation

### Full Implementation

```ruby
# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API Auth - User Registration', swagger_doc: 'v1/swagger.yaml' do
  path '/api/auth/sign-up' do
    post 'Register a new user account' do
      tags 'Authentication'
      description <<~DESC
        Creates a new user account with email/password authentication.
        Requires acceptance of platform agreements (privacy policy, terms of service, code of conduct).
        Sends a confirmation email to verify the email address.
        
        **Note:** Users must confirm their email before they can sign in.
      DESC
      consumes 'application/json'
      produces 'application/json'

      parameter name: :registration, in: :body, required: true, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            description: 'User credentials and profile information',
            properties: {
              email: {
                type: :string,
                format: :email,
                example: 'newuser@example.com',
                description: 'User email address (must be unique)'
              },
              password: {
                type: :string,
                format: :password,
                minLength: 8,
                example: 'SecurePassword123!',
                description: 'Password (minimum 8 characters, mix of letters, numbers, symbols recommended)'
              },
              password_confirmation: {
                type: :string,
                format: :password,
                example: 'SecurePassword123!',
                description: 'Password confirmation (must match password)'
              },
              person_attributes: {
                type: :object,
                description: 'Associated person profile information',
                properties: {
                  name: {
                    type: :string,
                    example: 'John Doe',
                    description: 'Display name for the person'
                  },
                  identifier: {
                    type: :string,
                    example: 'john-doe',
                    description: 'Unique URL-friendly identifier'
                  },
                  description: {
                    type: :string,
                    example: 'Software developer and community organizer',
                    description: 'Brief bio or description (optional)'
                  }
                },
                required: %w[name identifier]
              }
            },
            required: %w[email password password_confirmation person_attributes]
          },
          privacy_policy_agreement: {
            type: :string,
            enum: %w[0 1],
            example: '1',
            description: 'Acceptance of privacy policy (1 = accepted)'
          },
          terms_of_service_agreement: {
            type: :string,
            enum: %w[0 1],
            example: '1',
            description: 'Acceptance of terms of service (1 = accepted)'
          },
          code_of_conduct_agreement: {
            type: :string,
            enum: %w[0 1],
            example: '1',
            description: 'Acceptance of code of conduct (1 = accepted)'
          }
        },
        required: %w[user privacy_policy_agreement terms_of_service_agreement code_of_conduct_agreement]
      }

      # Success Response
      response '201', 'User created successfully' do
        schema type: :object,
               description: 'Successful registration response',
               properties: {
                 message: {
                   type: :string,
                   example: 'Welcome! You have signed up successfully.',
                   description: 'Success message'
                 },
                 data: {
                   type: :object,
                   description: 'User data (JSONAPI format)',
                   properties: {
                     type: {
                       type: :string,
                       example: 'users',
                       description: 'Resource type'
                     },
                     id: {
                       type: :string,
                       format: :uuid,
                       example: '550e8400-e29b-41d4-a716-446655440000',
                       description: 'User UUID'
                     },
                     attributes: {
                       type: :object,
                       properties: {
                         email: {
                           type: :string,
                           example: 'newuser@example.com',
                           description: 'User email address'
                         },
                         confirmed: {
                           type: :boolean,
                           example: false,
                           description: 'Email confirmation status (false until user clicks confirmation link)'
                         }
                       }
                     }
                   },
                   required: %w[type id attributes]
                 }
               },
               required: %w[message data]

        let(:registration) do
          {
            user: {
              email: 'newuser@example.com',
              password: 'SecureTest123!@#',
              password_confirmation: 'SecureTest123!@#',
              person_attributes: {
                name: 'Test User',
                identifier: 'test-user',
                description: 'Test user description'
              }
            },
            privacy_policy_agreement: '1',
            terms_of_service_agreement: '1',
            code_of_conduct_agreement: '1'
          }
        end

        run_test! do |response|
          # Verify response structure
          json = JSON.parse(response.body)
          expect(json).to have_key('data')
          expect(json['data']['type']).to eq('users')
          expect(json['data']['attributes']['email']).to eq('newuser@example.com')
          expect(json['data']['attributes']['confirmed']).to be false

          # Verify security - no password exposure
          expect(json['data']['attributes']).not_to have_key('password')
          expect(json['data']['attributes']).not_to have_key('encrypted_password')

          # Verify database records created
          expect(BetterTogether::User.find_by(email: 'newuser@example.com')).to be_present
          expect(BetterTogether::Person.find_by(identifier: 'test-user')).to be_present
        end
      end

      # Validation Error: Missing Email
      response '422', 'Missing required field (email)' do
        schema type: :object,
               description: 'Validation error response',
               properties: {
                 errors: {
                   type: :array,
                   items: {
                     type: :string
                   },
                   example: ["Email can't be blank"],
                   description: 'Array of validation error messages'
                 }
               },
               required: %w[errors]

        let(:registration) do
          {
            user: {
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
          json = JSON.parse(response.body)
          expect(json).to have_key('errors')
          expect(json['errors']).to be_an(Array)
          expect(json['errors']).not_to be_empty
        end
      end

      # Validation Error: Invalid Email Format
      response '422', 'Invalid email format' do
        schema '$ref' => '#/components/schemas/ValidationErrors'

        let(:registration) do
          {
            user: {
              email: 'not-an-email',
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
          json = JSON.parse(response.body)
          expect(json['errors']).to include(match(/email/i))
        end
      end

      # Validation Error: Duplicate Email
      response '422', 'Email already exists' do
        schema '$ref' => '#/components/schemas/ValidationErrors'

        let!(:existing_user) { create(:better_together_user, email: 'existing@example.com') }
        let(:registration) do
          {
            user: {
              email: 'existing@example.com',
              password: 'SecureTest123!@#',
              password_confirmation: 'SecureTest123!@#',
              person_attributes: {
                name: 'Test User',
                identifier: 'test-user-duplicate'
              }
            },
            privacy_policy_agreement: '1',
            terms_of_service_agreement: '1',
            code_of_conduct_agreement: '1'
          }
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['errors']).to include(match(/email.*taken|already.*exists/i))
        end
      end

      # Validation Error: Weak Password
      response '422', 'Password too short' do
        schema '$ref' => '#/components/schemas/ValidationErrors'

        let(:registration) do
          {
            user: {
              email: 'newuser@example.com',
              password: '12345',
              password_confirmation: '12345',
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
          json = JSON.parse(response.body)
          expect(json['errors']).to include(match(/password.*short|minimum.*characters/i))
        end
      end
    end
  end
end
```

---

## Shared Schema Components

Add to `spec/swagger_helper.rb` in the `swagger_docs` configuration:

```ruby
config.swagger_docs = {
  'v1/swagger.yaml' => {
    openapi: '3.0.1',
    info: {
      title: 'Community Engine API',
      version: 'v1',
      description: <<~DESC
        Better Together Community Engine REST API
        
        ## Authentication
        
        Most endpoints require JWT authentication via Bearer token in the Authorization header.
        See the Authentication section for how to obtain tokens via sign-in.
      DESC
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
    ],
    components: {
      schemas: {
        ValidationErrors: {
          type: :object,
          description: 'Standard validation error response format',
          properties: {
            errors: {
              type: :array,
              items: { type: :string },
              description: 'Array of human-readable error messages',
              example: ["Email can't be blank", "Password is too short"]
            }
          },
          required: %w[errors]
        },
        User: {
          type: :object,
          description: 'User resource (JSONAPI format)',
          properties: {
            type: {
              type: :string,
              enum: %w[users],
              example: 'users'
            },
            id: {
              type: :string,
              format: :uuid,
              example: '550e8400-e29b-41d4-a716-446655440000'
            },
            attributes: {
              type: :object,
              properties: {
                email: { type: :string, format: :email },
                confirmed: { type: :boolean, description: 'Email confirmation status' }
              }
            }
          },
          required: %w[type id attributes]
        }
      }
    }
  }
}
```

---

## Implementation Checklist

### Phase 1: Fix Failing Tests (BLOCKER)

- [ ] **Fix NameError in registrations controller** - controller is throwing errors
  - Issue appears to be with `&block` parameter handling
  - All 13 test failures stem from this
  - Must fix before adding rswag spec

### Phase 2: Create Rswag Spec

- [ ] Create directory: `spec/integration/api/auth/`
- [ ] Create file: `spec/integration/api/auth/registrations_spec.rb`
- [ ] Add shared schema components to `spec/swagger_helper.rb`
- [ ] Copy implementation from template above
- [ ] Run spec to verify it passes: `bin/dc-run bundle exec rspec spec/integration/api/auth/registrations_spec.rb`

### Phase 3: Generate Documentation

- [ ] Generate Swagger docs: `bin/dc-run bundle exec rake rswag:specs:swaggerize`
- [ ] Review generated `swagger/v1/swagger.yaml`
- [ ] Verify request/response schemas are complete
- [ ] Check examples render correctly

### Phase 4: Verify Both Specs Work Together

- [ ] Run existing spec: `bin/dc-run bundle exec prspec spec/requests/better_together/api/auth/registrations_api_spec.rb`
- [ ] Run rswag spec: `bin/dc-run bundle exec rspec spec/integration/api/auth/registrations_spec.rb`
- [ ] Run full test suite: `bin/dc-run bin/ci`
- [ ] Verify no test conflicts or duplication issues

### Phase 5: Documentation Review

- [ ] Review Swagger UI (if mounted): visit `/bt/api/docs`
- [ ] Test "Try it out" functionality with example payloads
- [ ] Verify error response examples are clear and helpful
- [ ] Ensure security note about email confirmation is visible

---

## Expected Outcomes

### Swagger Documentation Will Include:

1. **Complete endpoint description** with usage notes
2. **Full request schema** with all required/optional fields
3. **Example request payload** that works out-of-the-box
4. **Success response schema** with JSONAPI structure
5. **5 documented error scenarios** with examples
6. **Field descriptions** explaining each parameter
7. **Validation rules** (min length, format, enums)
8. **Security notes** about confirmation flow

### Test Coverage Will Remain:

1. **15 existing test cases** still running and passing
2. **5 new rswag tests** for documentation
3. **Zero duplication** - different purposes, complementary coverage
4. **Both specs maintainable** independently

### API Consumers Will Get:

1. **Interactive documentation** via Swagger UI
2. **Copy-paste examples** that work immediately
3. **Clear error messages** for debugging
4. **Type safety** via OpenAPI schema
5. **Client SDK generation** capability (future)

---

## Testing the Implementation

### Step-by-Step Verification

```bash
# 1. Fix controller first (required before proceeding)
# Address the NameError in the create method

# 2. Run existing spec to verify fix
bin/dc-run bundle exec prspec spec/requests/better_together/api/auth/registrations_api_spec.rb

# 3. Create and run rswag spec
bin/dc-run bundle exec rspec spec/integration/api/auth/registrations_spec.rb

# 4. Generate Swagger documentation
bin/dc-run bundle exec rake rswag:specs:swaggerize

# 5. Verify generated YAML
cat swagger/v1/swagger.yaml | grep -A 20 "post.*sign-up"

# 6. Run both specs together
bin/dc-run bundle exec prspec spec/requests/better_together/api/auth/registrations_api_spec.rb spec/integration/api/auth/registrations_spec.rb
```

---

## Maintenance Guidelines

### When to Update Rswag Spec

✅ **Update when:**
- Request/response structure changes
- New required parameters added
- New validation rules added
- Important error scenarios change
- Example payload needs updating

❌ **Don't update for:**
- Internal implementation changes
- Performance optimizations
- Refactoring that doesn't affect API contract
- Bug fixes that don't change behavior

### When to Update Existing Spec

✅ **Update when:**
- Adding new edge case tests
- Testing internal side effects (emails, database)
- Security vulnerability tests
- Complex validation scenarios
- Race condition tests

---

## Benefits of This Approach

### For Development Team

1. **Comprehensive test coverage** - detailed tests unchanged
2. **API documentation automated** - no manual Swagger writing
3. **Single source of truth** - tests generate docs
4. **Flexibility** - can evolve specs independently
5. **No test duplication** - clear separation of concerns

### For API Consumers

1. **Always up-to-date docs** - generated from passing tests
2. **Working examples** - copy-paste ready
3. **Clear error handling** - know what to expect
4. **Type safety** - OpenAPI schema validation
5. **Interactive testing** - try API directly in browser

### For Product/Business

1. **Faster onboarding** - developers can self-serve
2. **Fewer support tickets** - clear documentation
3. **Better integrations** - partners can build with confidence
4. **Professional appearance** - standardized API docs
5. **SDK generation** - auto-generate client libraries

---

## Next Steps After Registrations

Once registrations spec is working, apply same pattern to:

1. **Sessions** (`POST /api/auth/sign-in`, `DELETE /api/auth/sign-out`)
2. **Passwords** (`POST /api/auth/password`, `PATCH /api/auth/password`)
3. **Confirmations** (`GET /api/auth/confirmation`)
4. **People** (`GET/POST/PATCH /api/v1/people`)
5. **Communities** (`GET/POST/PATCH /api/v1/communities`)

Each spec follows the same pattern:
- Keep existing detailed spec
- Add companion rswag spec with 3-5 key scenarios
- Generate documentation
- Validate with Swagger UI

**Estimated time per resource:** 1-2 hours once pattern established.
