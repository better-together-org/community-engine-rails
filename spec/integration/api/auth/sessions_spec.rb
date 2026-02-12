# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API Auth - Sessions', :skip_host_setup, type: :request do
  let(:user) { create(:better_together_user, :confirmed, password: 'SecureTest123!@#', password_confirmation: 'SecureTest123!@#') }

  before do
    configure_host_platform
    user
  end

  path '/api/auth/sign-in' do
    post 'Sign in to get JWT token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description 'Authenticate with email and password to receive a JWT token in the Authorization header'

      parameter name: :credentials,
                in: :body,
                required: true,
                schema: {
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
                  required: ['user']
                }

      response '200', 'user signed in successfully' do
        let(:credentials) do
          {
            user: {
              email: user.email,
              password: 'SecureTest123!@#'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     type: { type: :string, example: 'sessions' },
                     id: { type: :string },
                     attributes: {
                       type: :object,
                       properties: {
                         email: { type: :string },
                         token: { type: :string },
                         confirmed: { type: :boolean }
                       }
                     },
                     relationships: {
                       type: :object,
                       properties: {
                         person: {
                           type: :object,
                           properties: {
                             data: {
                               type: :object,
                               properties: {
                                 type: { type: :string, example: 'people' },
                                 id: { type: :string, format: :uuid }
                               }
                             }
                           }
                         }
                       }
                     }
                   }
                 },
                 included: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       type: { type: :string },
                       id: { type: :string },
                       attributes: { type: :object }
                     }
                   }
                 }
               },
               required: ['data']

        run_test! do |response|
          expect(response.headers['Authorization']).to be_present
          expect(response.headers['Authorization']).to start_with('Bearer ')
        end
      end

      response '401', 'invalid credentials' do
        let(:credentials) do
          {
            user: {
              email: user.email,
              password: 'WrongPassword'
            }
          }
        end

        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        run_test!
      end
    end
  end

  path '/api/auth/sign-out' do
    delete 'Sign out (revoke JWT token)' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description 'Sign out and invalidate the current JWT token'
      security [{ bearer_auth: [] }]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: 'JWT token',
                example: 'Bearer eyJhbGciOiJIUzI1NiJ9...'

      response '200', 'user signed out successfully' do
        let(:token) { api_sign_in_and_get_token(user) }
        let(:Authorization) { "Bearer #{token}" }

        schema type: :object,
               properties: {
                 message: { type: :string }
               }

        run_test!
      end

      response '401', 'unauthorized - no valid token' do
        let(:Authorization) { '' }

        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        run_test!
      end
    end
  end
end
