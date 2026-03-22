# frozen_string_literal: true

require 'swagger_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'Webhook Endpoints API', :no_auth, type: :request do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:Authorization) { "Bearer #{api_sign_in_and_get_token(user)}" } # rubocop:disable RSpec/VariableName

  path '/api/v1/webhook_endpoints' do
    get 'List webhook endpoints' do
      tags 'Webhooks'
      security [{ bearer_auth: [] }]
      produces 'application/vnd.api+json'
      description "List the current user's registered webhook endpoints."

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'webhook endpoints listed' do
        run_test!
      end
    end

    post 'Create a webhook endpoint' do
      tags 'Webhooks'
      security [{ bearer_auth: [] }]
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'
      description 'Register a new webhook endpoint to receive event notifications.'

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          data: {
            type: :object,
            properties: {
              type: { type: :string, example: 'webhook_endpoints' },
              attributes: {
                type: :object,
                properties: {
                  url: { type: :string, format: :uri, description: 'URL to receive webhook events' },
                  events: {
                    type: :array,
                    items: { type: :string },
                    description: 'List of event types to subscribe to',
                    example: %w[post.created event.published]
                  },
                  active: { type: :boolean, default: true }
                },
                required: %w[url]
              }
            },
            required: %w[type attributes]
          }
        },
        required: %w[data]
      }

      response '201', 'webhook endpoint created' do
        let(:pm_user) { create(:better_together_user, :confirmed, :platform_manager) }
        let(:Authorization) { "Bearer #{api_sign_in_and_get_token(pm_user)}" } # rubocop:disable RSpec/VariableName
        let(:body) do
          {
            data: {
              type: 'webhook_endpoints',
              attributes: {
                name: 'Test Webhook',
                url: 'https://myapp.example.com/webhooks',
                events: ['post.created'],
                active: true
              }
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/webhook_endpoints/{id}' do
    parameter name: :id, in: :path, type: :string, format: :uuid, required: true

    let!(:webhook) { create(:better_together_webhook_endpoint, person: user.person) }
    let(:id) { webhook.id }

    get 'Get a webhook endpoint' do
      tags 'Webhooks'
      security [{ bearer_auth: [] }]
      produces 'application/vnd.api+json'

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'webhook endpoint found' do
        run_test!
      end
    end

    patch 'Update a webhook endpoint' do
      tags 'Webhooks'
      security [{ bearer_auth: [] }]
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          data: {
            type: :object,
            properties: {
              type: { type: :string, example: 'webhook_endpoints' },
              id: { type: :string, format: :uuid },
              attributes: {
                type: :object,
                properties: {
                  url: { type: :string, format: :uri },
                  active: { type: :boolean }
                }
              }
            },
            required: %w[type id attributes]
          }
        },
        required: %w[data]
      }

      response '200', 'webhook endpoint updated' do
        let(:body) { { data: { type: 'webhook_endpoints', id: webhook.id, attributes: { active: false } } } }
        run_test!
      end
    end

    delete 'Delete a webhook endpoint' do
      tags 'Webhooks'
      security [{ bearer_auth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'webhook endpoint deleted' do
        run_test!
      end
    end
  end

  path '/api/v1/webhook_endpoints/{id}/test' do
    parameter name: :id, in: :path, type: :string, format: :uuid, required: true

    let!(:webhook) { create(:better_together_webhook_endpoint, person: user.person) }
    let(:id) { webhook.id }

    post 'Send a test webhook delivery' do
      tags 'Webhooks'
      security [{ bearer_auth: [] }]
      produces 'application/json'
      description 'Trigger a test delivery to verify the webhook endpoint is reachable.'

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '202', 'test delivery triggered' do
        run_test!
      end
    end
  end

  path '/api/v1/webhooks/receive' do
    post 'Receive an inbound webhook' do
      tags 'Webhooks'
      consumes 'application/json'
      produces 'application/json'
      description 'Inbound webhook endpoint for receiving events from external systems. Requires OAuth Bearer token with admin scope.'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'OAuth Bearer token with admin scope'
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        description: 'Arbitrary event payload from the external system'
      }

      response '401', 'missing or invalid OAuth token' do
        let(:Authorization) { nil } # rubocop:disable RSpec/VariableName
        let(:body) { { event: 'ping', payload: {} } }
        run_test!
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
