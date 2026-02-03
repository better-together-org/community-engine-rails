# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API Auth - Passwords', :skip_host_setup, type: :request do
  let(:user) { create(:better_together_user, :confirmed, password: 'SecureTest123!@#', password_confirmation: 'SecureTest123!@#') }

  before do
    configure_host_platform
    user
  end

  path '/api/auth/password' do
    post 'Request password reset email' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description 'Send password reset instructions to the user email. Returns success even for non-existent emails to prevent email enumeration.'

      parameter name: :email_params,
                in: :body,
                required: true,
                schema: {
                  type: :object,
                  properties: {
                    user: {
                      type: :object,
                      properties: {
                        email: { type: :string, example: 'user@example.com' }
                      },
                      required: ['email']
                    }
                  },
                  required: ['user']
                }

      response '200', 'password reset email sent (or email not found)' do
        let(:email_params) do
          {
            user: {
              email: user.email
            }
          }
        end

        schema type: :object,
               properties: {
                 message: { type: :string }
               }

        run_test!
      end
    end

    put 'Reset password with token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description 'Reset password using the token received via email'

      parameter name: :reset_params,
                in: :body,
                required: true,
                schema: {
                  type: :object,
                  properties: {
                    user: {
                      type: :object,
                      properties: {
                        reset_password_token: { type: :string, example: 'abc123token' },
                        password: { type: :string, example: 'NewSecurePassword123!@#' },
                        password_confirmation: { type: :string, example: 'NewSecurePassword123!@#' }
                      },
                      required: %w[reset_password_token password password_confirmation]
                    }
                  },
                  required: ['user']
                }

      response '204', 'password reset successfully' do
        let(:reset_token) { user.send_reset_password_instructions }
        let(:reset_params) do
          {
            user: {
              reset_password_token: reset_token,
              password: 'NewSecure456!@#',
              password_confirmation: 'NewSecure456!@#'
            }
          }
        end

        run_test!
      end

      response '422', 'invalid reset token or password' do
        let(:reset_params) do
          {
            user: {
              reset_password_token: 'invalid_token',
              password: 'NewSecure456!@#',
              password_confirmation: 'NewSecure456!@#'
            }
          }
        end

        schema type: :object,
               properties: {
                 errors: {
                   oneOf: [
                     {
                       type: :array,
                       items: { type: :string }
                     },
                     {
                       type: :object,
                       additionalProperties: {
                         type: :array,
                         items: { type: :string }
                       }
                     }
                   ]
                 }
               }

        run_test!
      end
    end
  end
end
