# frozen_string_literal: true

require 'swagger_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'OAuth Applications API', type: :request, no_auth: true do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:Authorization) { "Bearer #{api_sign_in_and_get_token(user)}" }

  path '/api/oauth_applications' do
    get 'List OAuth applications' do
      tags 'OAuth'
      security [bearer_auth: []]
      produces 'application/json'
      description "List the current user's registered OAuth applications."

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'applications listed' do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string, format: :uuid },
                       name: { type: :string },
                       uid: { type: :string },
                       scopes: { type: :string }
                     }
                   }
                 }
               }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid' }
        run_test!
      end
    end

    post 'Create an OAuth application' do
      tags 'OAuth'
      security [bearer_auth: []]
      consumes 'application/json'
      produces 'application/json'
      description 'Register a new OAuth application for API access.'

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          oauth_application: {
            type: :object,
            properties: {
              name: { type: :string, description: 'Application name' },
              redirect_uri: { type: :string, description: 'Redirect URI for OAuth flow' },
              scopes: { type: :string, description: 'Space-separated list of scopes', example: 'read write mcp_access' }
            },
            required: %w[name redirect_uri]
          }
        },
        required: %w[oauth_application]
      }

      response '201', 'application created' do
        let(:body) do
          {
            oauth_application: {
              name: "My App #{SecureRandom.hex(4)}",
              redirect_uri: 'https://myapp.example.com/callback',
              scopes: 'read'
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/oauth_applications/{id}' do
    parameter name: :id, in: :path, type: :string, format: :uuid, required: true

    let!(:oauth_app_record) { create(:better_together_oauth_application, owner: user.person) }
    let(:id) { oauth_app_record.id }

    get 'Get an OAuth application' do
      tags 'OAuth'
      security [bearer_auth: []]
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'application found' do
        run_test!
      end

      response '404', 'not found' do
        let(:id) { SecureRandom.uuid }
        run_test!
      end
    end

    delete 'Delete an OAuth application' do
      tags 'OAuth'
      security [bearer_auth: []]
      description 'Delete an OAuth application. Only the owner can delete their app.'

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'application deleted' do
        run_test!
      end
    end
  end
end

RSpec.describe 'Doorkeeper OAuth Token Endpoint', type: :request, no_auth: true do
  path '/api/oauth/token' do
    post 'Request OAuth2 access token' do
      tags 'OAuth'
      consumes 'application/x-www-form-urlencoded'
      produces 'application/json'
      description <<~DESC
        Request an OAuth2 access token using client_credentials or authorization_code grant.

        **client_credentials grant** — for server-to-server API access:
        ```
        grant_type=client_credentials&client_id=...&client_secret=...&scope=read+write
        ```

        **authorization_code grant** — for user-delegated access:
        ```
        grant_type=authorization_code&code=...&redirect_uri=...&client_id=...&client_secret=...
        ```
      DESC

      parameter name: :grant_type, in: :formData, type: :string, required: true,
                enum: %w[client_credentials authorization_code],
                description: 'OAuth2 grant type'
      parameter name: :client_id, in: :formData, type: :string, required: true
      parameter name: :client_secret, in: :formData, type: :string, required: true
      parameter name: :scope, in: :formData, type: :string, required: false,
                description: 'Space-separated scopes', example: 'read write mcp_access'
      parameter name: :code, in: :formData, type: :string, required: false,
                description: 'Authorization code (authorization_code grant only)'
      parameter name: :redirect_uri, in: :formData, type: :string, required: false

      response '200', 'access token issued' do
        schema type: :object,
               properties: {
                 access_token: { type: :string },
                 token_type: { type: :string, example: 'Bearer' },
                 expires_in: { type: :integer, example: 7200 },
                 scope: { type: :string }
               }
        let(:oauth_app) { create(:better_together_oauth_application, scopes: 'read') }
        let(:grant_type) { 'client_credentials' }
        let(:client_id) { oauth_app.uid }
        let(:client_secret) { oauth_app.plaintext_secret }
        let(:scope) { 'read' }
        run_test!
      end

      response '401', 'invalid client credentials' do
        schema type: :object, properties: { error: { type: :string }, error_description: { type: :string } }
        let(:grant_type) { 'client_credentials' }
        let(:client_id) { 'invalid' }
        let(:client_secret) { 'invalid' }
        run_test!
      end
    end
  end

  path '/api/oauth/revoke' do
    post 'Revoke an OAuth2 token' do
      tags 'OAuth'
      consumes 'application/x-www-form-urlencoded'
      produces 'application/json'
      description 'Revoke an access token or refresh token.'

      parameter name: :token, in: :formData, type: :string, required: true, description: 'Token to revoke'
      parameter name: :client_id, in: :formData, type: :string, required: true
      parameter name: :client_secret, in: :formData, type: :string, required: true

      response '200', 'token revoked (or already invalid)' do
        let(:oauth_app) { create(:better_together_oauth_application, scopes: 'read') }
        let(:access_token) { create(:better_together_oauth_access_token, application: oauth_app, scopes: 'read') }
        let(:token) { access_token.token }
        let(:client_id) { oauth_app.uid }
        let(:client_secret) { oauth_app.plaintext_secret }
        run_test!
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
