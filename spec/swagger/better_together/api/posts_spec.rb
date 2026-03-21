# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Posts API', :no_auth, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:user) { create(:better_together_user, :confirmed) }
  let(:Authorization) { "Bearer #{api_sign_in_and_get_token(user)}" } # rubocop:disable RSpec/VariableName

  path '/api/v1/posts' do
    get 'List posts' do
      tags 'Posts'
      security [{ bearer_auth: [] }]
      produces 'application/vnd.api+json'
      description 'List posts accessible to the current user, filtered by privacy and published status.'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer JWT token'
      parameter name: :'page[number]', in: :query, type: :integer, required: false
      parameter name: :'page[size]', in: :query, type: :integer, required: false

      response '200', 'posts listed' do
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid' } # rubocop:disable RSpec/VariableName
        run_test!
      end
    end

    post 'Create a post' do
      tags 'Posts'
      security [{ bearer_auth: [] }]
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'
      description 'Create a new post. Requires authentication.'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer JWT token'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          data: {
            type: :object,
            properties: {
              type: { type: :string, example: 'posts' },
              attributes: {
                type: :object,
                properties: {
                  title: { type: :string },
                  content: { type: :string },
                  privacy: { type: :string, enum: %w[public private] }
                },
                required: %w[title]
              }
            },
            required: %w[type attributes]
          }
        },
        required: %w[data]
      }

      response '201', 'post created' do
        let(:pm_user) { create(:better_together_user, :confirmed, :platform_manager) }
        let(:Authorization) { "Bearer #{api_sign_in_and_get_token(pm_user)}" } # rubocop:disable RSpec/VariableName
        let(:body) do
          { data: { type: 'posts', attributes: { title: 'Test Post', content: 'Content', privacy: 'public' } } }
        end
        run_test!
      end
    end
  end

  path '/api/v1/posts/{id}' do
    parameter name: :id, in: :path, type: :string, format: :uuid, required: true,
              description: 'Post UUID'

    let(:pm_user) { create(:better_together_user, :confirmed, :platform_manager) }
    let!(:post_record) { create(:better_together_post, privacy: 'public', published_at: 1.day.ago, author: pm_user.person) }
    let(:id) { post_record.id }

    get 'Get a post' do
      tags 'Posts'
      security [{ bearer_auth: [] }]
      produces 'application/vnd.api+json'
      description 'Get a post by ID. Public published posts are accessible to all authenticated users.'

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'post found' do
        run_test!
      end

      response '404', 'not found' do
        let(:id) { SecureRandom.uuid }
        run_test!
      end
    end

    patch 'Update a post' do
      tags 'Posts'
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
              type: { type: :string, example: 'posts' },
              id: { type: :string, format: :uuid },
              attributes: { type: :object, properties: { title: { type: :string }, content: { type: :string } } }
            },
            required: %w[type id attributes]
          }
        },
        required: %w[data]
      }

      response '200', 'post updated' do
        let(:Authorization) { "Bearer #{api_sign_in_and_get_token(pm_user)}" } # rubocop:disable RSpec/VariableName
        let(:body) { { data: { type: 'posts', id: post_record.id, attributes: { title: 'Updated' } } } }
        run_test!
      end
    end

    delete 'Delete a post' do
      tags 'Posts'
      security [{ bearer_auth: [] }]
      description 'Delete a post. Requires ownership or manage_platform permission.'

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'post deleted' do
        let(:Authorization) { "Bearer #{api_sign_in_and_get_token(pm_user)}" } # rubocop:disable RSpec/VariableName
        run_test!
      end
    end
  end
end
