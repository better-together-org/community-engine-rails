# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API Auth - Registrations', :skip_host_setup, type: :request do
  before do
    configure_host_platform
  end

  path '/api/auth/sign-up' do
    post 'Register a new user account' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description 'Create a new user account with email, password, and person details. Sends a confirmation email.'

      parameter name: :registration,
                in: :body,
                required: true,
                schema: {
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
                            identifier: { type: :string, example: 'john-doe' },
                            description: { type: :string, example: 'Software developer' }
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
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid registration data' do
        let(:registration) do
          {
            user: {
              email: 'invalid-email',
              password: 'short',
              password_confirmation: 'different'
            },
            privacy_policy_agreement: '1',
            terms_of_service_agreement: '1',
            code_of_conduct_agreement: '1'
          }
        end

        schema type: :object,
               properties: {
                 errors: {
                   type: :array,
                   items: { type: :string }
                 }
               }

        run_test!
      end
    end
  end
end
