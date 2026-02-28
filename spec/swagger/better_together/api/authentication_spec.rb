# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Authentication', :no_auth, type: :request do # rubocop:disable RSpec/DescribeClass
  path '/api/auth/sign-in' do
    post 'Sign in to get JWT token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description 'Authenticate with email and password. Returns a JWT token in the response body.'

      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, example: 'user@example.com' },
              password: { type: :string, example: 'SecurePassword123!@#' }
            },
            required: %w[email password]
          }
        },
        required: %w[user]
      }

      response '200', 'signed in successfully' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     type: { type: :string, example: 'sessions' },
                     id: { type: :string, format: :uuid },
                     attributes: {
                       type: :object,
                       properties: {
                         email: { type: :string },
                         token: { type: :string, description: 'JWT Bearer token' },
                         confirmed: { type: :boolean }
                       }
                     }
                   }
                 }
               }

        let(:user) { create(:better_together_user, :confirmed) }
        let(:body) { { user: { email: user.email, password: 'SecureTest123!@#' } } }
        run_test!
      end

      response '401', 'invalid credentials' do
        schema type: :object, properties: { error: { type: :string } }
        let(:body) { { user: { email: 'bad@example.com', password: 'wrong' } } }
        run_test!
      end
    end
  end

  path '/api/auth/sign-out' do
    delete 'Sign out (revoke JWT token)' do
      tags 'Authentication'
      security [bearer_auth: []]
      produces 'application/json'
      description 'Sign out and invalidate the current JWT token.'
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer JWT token',
                example: 'Bearer eyJhbGciOiJIUzI1NiJ9...'

      response '200', 'signed out successfully' do
        schema type: :object, properties: { message: { type: :string } }
        let(:user) { create(:better_together_user, :confirmed) }
        let(:Authorization) { "Bearer #{api_sign_in_and_get_token(user)}" } # rubocop:disable RSpec/VariableName
        run_test!
      end
    end
  end

  path '/api/auth/sign-up' do
    post 'Register a new user account' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description 'Create a new user account. Sends a confirmation email.'

      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, example: 'newuser@example.com' },
              password: { type: :string, example: 'SecurePassword123!@#' },
              password_confirmation: { type: :string, example: 'SecurePassword123!@#' },
              person_attributes: {
                type: :object,
                properties: {
                  name: { type: :string, example: 'John Doe' },
                  identifier: { type: :string, example: 'john-doe' }
                },
                required: %w[name identifier]
              }
            },
            required: %w[email password password_confirmation person_attributes]
          },
          privacy_policy_agreement: { type: :string, example: '1' },
          terms_of_service_agreement: { type: :string, example: '1' },
          code_of_conduct_agreement: { type: :string, example: '1' }
        },
        required: %w[user privacy_policy_agreement terms_of_service_agreement code_of_conduct_agreement]
      }

      response '201', 'user registered successfully' do
        let(:body) do
          {
            user: {
              email: "swagger-test-#{SecureRandom.hex(4)}@example.com",
              password: 'SecureTest123!@#',
              password_confirmation: 'SecureTest123!@#',
              person_attributes: { name: 'Swagger Test', identifier: "swagger-#{SecureRandom.hex(4)}" }
            },
            privacy_policy_agreement: '1',
            terms_of_service_agreement: '1',
            code_of_conduct_agreement: '1'
          }
        end
        run_test!
      end

      response '422', 'invalid registration data' do
        schema '$ref' => '#/components/schemas/ValidationErrors'
        let(:body) { { user: { email: 'bad', password: 'x', password_confirmation: 'y', person_attributes: {} } } }
        run_test!
      end
    end
  end

  path '/api/auth/password' do
    post 'Request password reset email' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description 'Send password reset instructions to the user email.'

      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: { email: { type: :string, example: 'user@example.com' } },
            required: %w[email]
          }
        },
        required: %w[user]
      }

      response '200', 'password reset email sent (or email not found)' do
        schema type: :object, properties: { message: { type: :string } }
        let(:body) { { user: { email: 'anyone@example.com' } } }
        run_test!
      end
    end
  end

  path '/api/auth/confirmation' do
    post 'Resend confirmation email' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description 'Resend email confirmation instructions.'

      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: { email: { type: :string, example: 'user@example.com' } },
            required: %w[email]
          }
        },
        required: %w[user]
      }

      response '200', 'confirmation email sent (or email not found)' do
        schema type: :object, properties: { message: { type: :string } }
        let(:body) { { user: { email: 'anyone@example.com' } } }
        run_test!
      end
    end
  end
end
