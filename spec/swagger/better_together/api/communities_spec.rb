# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Communities API', type: :request, no_auth: true do # rubocop:disable RSpec/DescribeClass
  let(:user) { create(:better_together_user, :confirmed) }
  let(:Authorization) { "Bearer #{api_sign_in_and_get_token(user)}" }

  path '/api/v1/communities' do
    get 'List communities' do
      tags 'Communities'
      security [bearer_auth: []]
      produces 'application/vnd.api+json'
      description 'List communities accessible to the current user. Authentication required.'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer JWT token', example: 'Bearer eyJhbGciOiJIUzI1NiJ9...'
      parameter name: :'page[number]', in: :query, type: :integer, required: false,
                description: 'Page number'
      parameter name: :'page[size]', in: :query, type: :integer, required: false,
                description: 'Items per page'

      response '200', 'communities listed' do
        run_test!
      end

      response '401', 'unauthorized' do
        schema type: :object, properties: { error: { type: :string } }
        let(:Authorization) { 'Bearer invalid' }
        run_test!
      end
    end

    post 'Create a community' do
      tags 'Communities'
      security [bearer_auth: []]
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'
      description 'Create a new community. Requires create_community permission.'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer JWT token'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          data: {
            type: :object,
            properties: {
              type: { type: :string, example: 'communities' },
              attributes: {
                type: :object,
                properties: {
                  name: { type: :string },
                  description: { type: :string },
                  privacy: { type: :string, enum: %w[public private], default: 'public' }
                },
                required: %w[name]
              }
            },
            required: %w[type attributes]
          }
        },
        required: %w[data]
      }

      response '201', 'community created' do
        let(:pm_user) { create(:better_together_user, :confirmed, :platform_manager) }
        let(:Authorization) { "Bearer #{api_sign_in_and_get_token(pm_user)}" }
        let(:body) do
          {
            data: {
              type: 'communities',
              attributes: {
                name: "Test Community #{SecureRandom.hex(4)}",
                privacy: 'public'
              }
            }
          }
        end
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid' }
        let(:body) { { data: { type: 'communities', attributes: { name: 'Test' } } } }
        run_test!
      end
    end
  end

  path '/api/v1/communities/{id}' do
    parameter name: :id, in: :path, type: :string, format: :uuid, required: true,
              description: 'Community UUID'

    let!(:community) { create(:better_together_community, privacy: 'public') }
    let(:id) { community.id }

    get 'Get a community' do
      tags 'Communities'
      security [bearer_auth: []]
      produces 'application/vnd.api+json'
      description 'Retrieve a community by ID.'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer JWT token'

      response '200', 'community found' do
        run_test!
      end

      response '404', 'not found' do
        let(:id) { SecureRandom.uuid }
        run_test!
      end
    end

    patch 'Update a community' do
      tags 'Communities'
      security [bearer_auth: []]
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'
      description 'Update a community. Requires manage_community permission.'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer JWT token'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          data: {
            type: :object,
            properties: {
              type: { type: :string, example: 'communities' },
              id: { type: :string, format: :uuid },
              attributes: { type: :object, properties: { name: { type: :string } } }
            },
            required: %w[type id attributes]
          }
        },
        required: %w[data]
      }

      response '200', 'community updated' do
        let(:pm_user) { create(:better_together_user, :confirmed, :platform_manager) }
        let(:Authorization) { "Bearer #{api_sign_in_and_get_token(pm_user)}" }
        let(:body) { { data: { type: 'communities', id: community.id, attributes: { name: 'Updated Name' } } } }
        run_test!
      end
    end

    delete 'Delete a community' do
      tags 'Communities'
      security [bearer_auth: []]
      produces 'application/vnd.api+json'
      description 'Delete a community. Requires delete_community permission. Protected communities cannot be deleted.'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer JWT token'

      response '204', 'community deleted' do
        let!(:deletable) { create(:better_together_community, privacy: 'public', protected: false) }
        let(:id) { deletable.id }
        let(:pm_user) { create(:better_together_user, :confirmed, :platform_manager) }
        let(:Authorization) { "Bearer #{api_sign_in_and_get_token(pm_user)}" }
        run_test!
      end
    end
  end
end
