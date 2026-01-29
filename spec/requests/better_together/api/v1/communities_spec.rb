# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 - Communities', :skip_host_setup, type: :request do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_token) { api_sign_in_and_get_token(platform_manager_user) }

  before do
    configure_host_platform
    user
    person
  end

  path '/api/v1/communities' do
    get 'List all communities' do
      tags 'Communities'
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'
      description 'Retrieve a list of communities. Unauthenticated users only see public communities. Authenticated users see public communities and communities they have access to.'
      security [{ bearer_auth: [] }]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: false,
                description: 'JWT token (optional for public access)',
                example: 'Bearer eyJhbGciOiJIUzI1NiJ9...'

      parameter name: 'Accept',
                in: :header,
                type: :string,
                required: true,
                description: 'JSONAPI media type',
                schema: { type: :string, default: 'application/vnd.api+json' }

      parameter name: 'page[number]',
                in: :query,
                type: :integer,
                required: false,
                description: 'Page number for pagination'

      parameter name: 'page[size]',
                in: :query,
                type: :integer,
                required: false,
                description: 'Number of items per page'

      response '200', 'communities list retrieved' do
        let!(:public_community) { create(:better_together_community, privacy: 'public') }
        let!(:private_community) { create(:better_together_community, privacy: 'private') }
        let(:Authorization) { "Bearer #{token}" }
        let(:Accept) { 'application/vnd.api+json' }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       type: { type: :string, example: 'communities' },
                       id: { type: :string, format: :uuid },
                       attributes: {
                         type: :object,
                         properties: {
                           name: { type: :string },
                           slug: { type: :string },
                           privacy: { type: :string, enum: %w[public private] },
                           description: { type: :string, nullable: true }
                         }
                       }
                     }
                   }
                 }
               },
               required: ['data']

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['data']).to be_an(Array)
        end
      end
    end

    post 'Create a new community' do
      tags 'Communities'
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'
      description 'Create a new community. Requires authentication and create_community permission.'
      security [{ bearer_auth: [] }]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: 'JWT token',
                example: 'Bearer eyJhbGciOiJIUzI1NiJ9...'

      parameter name: 'Content-Type',
                in: :header,
                type: :string,
                required: true,
                description: 'JSONAPI media type',
                schema: { type: :string, default: 'application/vnd.api+json' }

      parameter name: :community,
                in: :body,
                required: true,
                schema: {
                  type: :object,
                  properties: {
                    data: {
                      type: :object,
                      properties: {
                        type: { type: :string, example: 'communities' },
                        attributes: {
                          type: :object,
                          properties: {
                            name: { type: :string, description: 'Community name' },
                            description: { type: :string, description: 'Community description' },
                            privacy: { type: :string, enum: %w[public private], default: 'public' }
                          },
                          required: %w[name]
                        }
                      },
                      required: %w[type attributes]
                    }
                  },
                  required: ['data']
                }

      response '201', 'community created' do
        let(:Authorization) { "Bearer #{platform_manager_token}" }
        let(:'Content-Type') { 'application/vnd.api+json' }
        let(:community) do
          {
            data: {
              type: 'communities',
              attributes: {
                name: 'New Community',
                description: 'A test community',
                privacy: 'public'
              }
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     type: { type: :string, example: 'communities' },
                     id: { type: :string, format: :uuid },
                     attributes: {
                       type: :object,
                       properties: {
                         name: { type: :string },
                         slug: { type: :string },
                         privacy: { type: :string }
                       }
                     }
                   }
                 }
               },
               required: ['data']

        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:'Content-Type') { 'application/vnd.api+json' }
        let(:community) do
          {
            data: {
              type: 'communities',
              attributes: { name: 'New Community' }
            }
          }
        end

        run_test!
      end

      response '404', 'forbidden - insufficient permissions' do
        let(:Authorization) { "Bearer #{token}" }
        let(:'Content-Type') { 'application/vnd.api+json' }
        let(:community) do
          {
            data: {
              type: 'communities',
              attributes: { name: 'New Community' }
            }
          }
        end

        run_test! do |response|
          # JSONAPI-resources policy scopes obscure authorization as 404
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  path '/api/v1/communities/{id}' do
    parameter name: :id,
              in: :path,
              type: :string,
              format: :uuid,
              description: 'Community ID'

    get 'Get a specific community' do
      tags 'Communities'
      produces 'application/vnd.api+json'
      description 'Retrieve a specific community by ID. Public communities are accessible to all. Private communities require authentication and membership.'
      security [{ bearer_auth: [] }]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: false,
                description: 'JWT token (optional for public communities)',
                example: 'Bearer eyJhbGciOiJIUzI1NiJ9...'

      parameter name: 'Accept',
                in: :header,
                type: :string,
                required: true,
                description: 'JSONAPI media type',
                schema: { type: :string, default: 'application/vnd.api+json' }

      response '200', 'community found' do
        let!(:public_community) { create(:better_together_community, privacy: 'public') }
        let(:id) { public_community.id }
        let(:Authorization) { "Bearer #{token}" }
        let(:Accept) { 'application/vnd.api+json' }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     type: { type: :string, example: 'communities' },
                     id: { type: :string, format: :uuid },
                     attributes: {
                       type: :object,
                       properties: {
                         name: { type: :string },
                         slug: { type: :string },
                         privacy: { type: :string }
                       }
                     }
                   }
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'community not found or not accessible' do
        let!(:private_community) { create(:better_together_community, privacy: 'private') }
        let(:id) { private_community.id }
        let(:Authorization) { "Bearer #{token}" }
        let(:Accept) { 'application/vnd.api+json' }

        run_test!
      end
    end

    patch 'Update a community' do
      tags 'Communities'
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'
      description 'Update a community. Requires authentication and update_community permission for the specific community.'
      security [{ bearer_auth: [] }]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: 'JWT token',
                example: 'Bearer eyJhbGciOiJIUzI1NiJ9...'

      parameter name: 'Content-Type',
                in: :header,
                type: :string,
                required: true,
                description: 'JSONAPI media type',
                schema: { type: :string, default: 'application/vnd.api+json' }

      parameter name: :community_update,
                in: :body,
                required: true,
                schema: {
                  type: :object,
                  properties: {
                    data: {
                      type: :object,
                      properties: {
                        type: { type: :string, example: 'communities' },
                        id: { type: :string, format: :uuid },
                        attributes: {
                          type: :object,
                          properties: {
                            name: { type: :string },
                            description: { type: :string }
                          }
                        }
                      },
                      required: %w[type id attributes]
                    }
                  },
                  required: ['data']
                }

      response '200', 'community updated' do
        let!(:test_community) { create(:better_together_community, creator: platform_manager_user.person) }
        let(:id) { test_community.id }
        let(:Authorization) { "Bearer #{platform_manager_token}" }
        let(:'Content-Type') { 'application/vnd.api+json' }
        let(:community_update) do
          {
            data: {
              type: 'communities',
              id: test_community.id,
              attributes: {
                name: 'Updated Name',
                description: 'Updated description'
              }
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     type: { type: :string, example: 'communities' },
                     id: { type: :string, format: :uuid },
                     attributes: {
                       type: :object,
                       properties: {
                         name: { type: :string }
                       }
                     }
                   }
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'community not found or not accessible' do
        let!(:other_community) { create(:better_together_community) }
        let(:id) { other_community.id }
        let(:Authorization) { "Bearer #{token}" }
        let(:'Content-Type') { 'application/vnd.api+json' }
        let(:community_update) do
          {
            data: {
              type: 'communities',
              id: other_community.id,
              attributes: {
                name: 'Updated Name'
              }
            }
          }
        end

        run_test!
      end
    end

    delete 'Delete a community' do
      tags 'Communities'
      produces 'application/vnd.api+json'
      description 'Delete a community. Requires delete_community permission. Protected communities cannot be deleted.'
      security [{ bearer_auth: [] }]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: 'JWT token',
                example: 'Bearer eyJhbGciOiJIUzI1NiJ9...'

      parameter name: 'Accept',
                in: :header,
                type: :string,
                required: true,
                description: 'JSONAPI media type',
                schema: { type: :string, default: 'application/vnd.api+json' }

      response '204', 'community deleted' do
        let!(:test_community) { create(:better_together_community, creator: platform_manager_user.person) }
        let(:id) { test_community.id }
        let(:Authorization) { "Bearer #{platform_manager_token}" }
        let(:Accept) { 'application/vnd.api+json' }

        run_test!
      end

      response '404', 'community not found, not accessible, or protected' do
        let!(:protected_community) { create(:better_together_community, protected: true, creator: platform_manager_user.person) }
        let(:id) { protected_community.id }
        let(:Authorization) { "Bearer #{platform_manager_token}" }
        let(:Accept) { 'application/vnd.api+json' }

        run_test! do |response|
          # Protected communities return 404 to obscure their protected status
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
