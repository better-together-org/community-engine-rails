# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API Authentication - Registrations', :skip_host_setup, type: :request do
  let(:test_user) { build(:better_together_user) }
  let(:agreement_params) do
    {
      privacy_policy_agreement: '1',
      terms_of_service_agreement: '1',
      code_of_conduct_agreement: '1'
    }
  end

  before do
    configure_host_platform
  end

  path '/api/auth/sign-up' do
    post 'Create a new user account' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description 'Register a new user account with email and password. Requires acceptance of platform agreements.'

      parameter name: 'Accept-Language',
                in: :header,
                type: :string,
                required: false,
                description: 'Preferred language for error messages',
                example: 'en'

      parameter name: :registration,
                in: :body,
                required: true,
                schema: {
                  type: :object,
                  properties: {
                    user: {
                      type: :object,
                      properties: {
                        email: {
                          type: :string,
                          format: :email,
                          description: 'User email address'
                        },
                        password: {
                          type: :string,
                          format: :password,
                          description: 'User password (minimum 8 characters, must include uppercase, lowercase, and special characters)',
                          minLength: 8
                        },
                        password_confirmation: {
                          type: :string,
                          format: :password,
                          description: 'Password confirmation (must match password)'
                        },
                        person_attributes: {
                          type: :object,
                          properties: {
                            name: {
                              type: :string,
                              description: 'Display name for the user'
                            },
                            identifier: {
                              type: :string,
                              description: 'Unique identifier/username for the user'
                            },
                            description: {
                              type: :string,
                              description: 'Optional profile description'
                            }
                          },
                          required: %w[name identifier]
                        }
                      },
                      required: %w[email password password_confirmation person_attributes]
                    },
                    privacy_policy_agreement: {
                      type: :string,
                      description: 'Must be "1" to indicate acceptance',
                      enum: ['1']
                    },
                    terms_of_service_agreement: {
                      type: :string,
                      description: 'Must be "1" to indicate acceptance',
                      enum: ['1']
                    },
                    code_of_conduct_agreement: {
                      type: :string,
                      description: 'Must be "1" to indicate acceptance',
                      enum: ['1']
                    }
                  },
                  required: %w[user privacy_policy_agreement terms_of_service_agreement code_of_conduct_agreement]
                }

      response '201', 'user created successfully' do
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
            **agreement_params
          }
        end

        schema type: :object,
               properties: {
                 message: {
                   type: :string,
                   description: 'Confirmation message about account status'
                 },
                 data: {
                   type: :object,
                   properties: {
                     type: { type: :string, example: 'users' },
                     id: { type: :string, format: :uuid },
                     attributes: {
                       type: :object,
                       properties: {
                         email: { type: :string, format: :email },
                         confirmed: {
                           type: :boolean,
                           description: 'Whether email is confirmed (false for new accounts)'
                         }
                       }
                     }
                   }
                 }
               },
               required: %w[message data]

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['data']['type']).to eq('users')
          expect(json['data']['attributes']['email']).to eq('newuser@example.com')
          expect(json['data']['attributes']['confirmed']).to be false
          expect(json['message']).to be_present
        end
      end

      response '422', 'missing email' do
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
            **agreement_params
          }
        end

        schema type: :object,
               properties: {
                 errors: {
                   type: :array,
                   items: { type: :string },
                   description: 'Array of validation error messages'
                 }
               },
               required: ['errors']

        run_test!
      end

      response '422', 'invalid email format' do
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
            **agreement_params
          }
        end

        schema type: :object,
               properties: {
                 errors: {
                   type: :array,
                   items: { type: :string }
                 }
               },
               required: ['errors']

        run_test!
      end

      response '422', 'weak password' do
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
            **agreement_params
          }
        end

        schema type: :object,
               properties: {
                 errors: {
                   type: :array,
                   items: { type: :string }
                 }
               },
               required: ['errors']

        run_test!
      end

      response '422', 'mismatched passwords' do
        let(:registration) do
          {
            user: {
              email: 'newuser@example.com',
              password: 'SecureTest123!@#',
              password_confirmation: 'DifferentSecure!',
              person_attributes: {
                name: 'Test User',
                identifier: 'test-user'
              }
            },
            **agreement_params
          }
        end

        schema type: :object,
               properties: {
                 errors: {
                   type: :array,
                   items: { type: :string }
                 }
               },
               required: ['errors']

        run_test!
      end

      response '422', 'missing agreements' do
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
            }
          }
        end

        schema type: :object,
               properties: {
                 errors: {
                   type: :array,
                   items: { type: :string }
                 }
               },
               required: ['errors']

        run_test!
      end
    end
  end
end
