# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API Auth - Confirmations', :skip_host_setup, type: :request do
  let(:user) { create(:better_together_user, confirmed_at: nil) }

  before do
    configure_host_platform
    user
  end

  path '/api/auth/confirmation' do
    post 'Resend confirmation email' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description 'Resend email confirmation instructions. Returns success even for non-existent emails to prevent email enumeration.'

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

      response '200', 'confirmation email sent (or email not found)' do
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

    get 'Confirm email with token' do
      tags 'Authentication'
      produces 'application/json'
      description 'Confirm user email address using the token received via email'

      parameter name: :confirmation_token,
                in: :query,
                type: :string,
                required: true,
                description: 'Confirmation token from email',
                example: 'abc123confirmtoken'

      response '200', 'email confirmed successfully' do
        let(:confirmation_token) do
          user.send_confirmation_instructions
          user.reload.confirmation_token
        end

        schema type: :object,
               properties: {
                 message: { type: :string }
               }

        run_test!
      end

      response '422', 'invalid or expired confirmation token' do
        let(:confirmation_token) { 'invalid_token' }

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
