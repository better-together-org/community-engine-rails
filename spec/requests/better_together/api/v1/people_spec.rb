# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 - People', :skip_host_setup, type: :request do
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

  path '/api/v1/people' do
    get 'List all people' do
      tags 'People'
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'
      description 'Retrieve a list of people. Unauthenticated users only see public profiles. Authenticated users see public profiles and their own profile.'
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

      response '200', 'people list retrieved' do
        let!(:public_person) { create(:better_together_person, privacy: 'public') }
        let!(:private_person) { create(:better_together_person, privacy: 'private') }
        let(:Authorization) { "Bearer #{token}" }
        let(:Accept) { 'application/vnd.api+json' }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       type: { type: :string, example: 'people' },
                       id: { type: :string, format: :uuid },
                       attributes: {
                         type: :object,
                         properties: {
                           name: { type: :string },
                           identifier: { type: :string },
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

    post 'Create a new person' do
      tags 'People'
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'
      description 'Create a new person profile. Requires authentication and create_person permission.'
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

      parameter name: :person,
                in: :body,
                required: true,
                schema: {
                  type: :object,
                  properties: {
                    data: {
                      type: :object,
                      properties: {
                        type: { type: :string, example: 'people' },
                        attributes: {
                          type: :object,
                          properties: {
                            name: { type: :string, description: 'Display name' },
                            identifier: { type: :string, description: 'Unique identifier/username' },
                            privacy: { type: :string, enum: %w[public private], default: 'public' },
                            description: { type: :string, description: 'Profile description' }
                          },
                          required: %w[name]
                        }
                      },
                      required: %w[type attributes]
                    }
                  },
                  required: ['data']
                }

      response '201', 'person created' do
        let(:Authorization) { "Bearer #{platform_manager_token}" }
        let(:'Content-Type') { 'application/vnd.api+json' }
        let(:person) do
          {
            data: {
              type: 'people',
              attributes: {
                name: 'New Person',
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
                     type: { type: :string, example: 'people' },
                     id: { type: :string, format: :uuid },
                     attributes: {
                       type: :object,
                       properties: {
                         name: { type: :string },
                         identifier: { type: :string },
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
        let(:person) do
          {
            data: {
              type: 'people',
              attributes: { name: 'New Person' }
            }
          }
        end

        run_test!
      end
    end
  end

  path '/api/v1/people/me' do
    get 'Get current user\'s person profile' do
      tags 'People'
      produces 'application/vnd.api+json'
      description 'Retrieve the authenticated user\'s person profile. Requires authentication.'
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

      response '200', 'current person retrieved' do
        let(:Authorization) { "Bearer #{token}" }
        let(:Accept) { 'application/vnd.api+json' }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     type: { type: :string, example: 'people' },
                     id: { type: :string, format: :uuid },
                     attributes: {
                       type: :object,
                       properties: {
                         name: { type: :string },
                         identifier: { type: :string },
                         email: { type: :string, format: :email }
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
        let(:Accept) { 'application/vnd.api+json' }

        run_test!
      end
    end
  end

  path '/api/v1/people/{id}' do
    parameter name: :id,
              in: :path,
              type: :string,
              format: :uuid,
              description: 'Person ID'

    get 'Get a specific person' do
      tags 'People'
      produces 'application/vnd.api+json'
      description 'Retrieve a specific person by ID. Public profiles are accessible to all. Private profiles require authentication and permission.'
      security [{ bearer_auth: [] }]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: false,
                description: 'JWT token (optional for public profiles)',
                example: 'Bearer eyJhbGciOiJIUzI1NiJ9...'

      parameter name: 'Accept',
                in: :header,
                type: :string,
                required: true,
                description: 'JSONAPI media type',
                schema: { type: :string, default: 'application/vnd.api+json' }

      response '200', 'person found' do
        let!(:public_person) { create(:better_together_person, privacy: 'public') }
        let(:id) { public_person.id }
        let(:Authorization) { "Bearer #{token}" }
        let(:Accept) { 'application/vnd.api+json' }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     type: { type: :string, example: 'people' },
                     id: { type: :string, format: :uuid },
                     attributes: {
                       type: :object,
                       properties: {
                         name: { type: :string },
                         identifier: { type: :string },
                         privacy: { type: :string }
                       }
                     }
                   }
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'person not found or not accessible' do
        let!(:private_person) { create(:better_together_person, privacy: 'private') }
        let(:id) { private_person.id }
        let(:Authorization) { "Bearer #{token}" }
        let(:Accept) { 'application/vnd.api+json' }

        run_test!
      end
    end

    patch 'Update a person' do
      tags 'People'
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'
      description 'Update a person profile. Users can update their own profile. Platform managers can update any profile.'
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

      parameter name: :person_update,
                in: :body,
                required: true,
                schema: {
                  type: :object,
                  properties: {
                    data: {
                      type: :object,
                      properties: {
                        type: { type: :string, example: 'people' },
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

      response '200', 'person updated' do
        let(:id) { person.id }
        let(:Authorization) { "Bearer #{token}" }
        let(:'Content-Type') { 'application/vnd.api+json' }
        let(:person_update) do
          {
            data: {
              type: 'people',
              id: person.id,
              attributes: {
                name: 'Updated Name'
              }
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     type: { type: :string, example: 'people' },
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

      response '404', 'person not found or not accessible' do
        let!(:other_person) { create(:better_together_person) }
        let(:id) { other_person.id }
        let(:Authorization) { "Bearer #{token}" }
        let(:'Content-Type') { 'application/vnd.api+json' }
        let(:person_update) do
          {
            data: {
              type: 'people',
              id: other_person.id,
              attributes: {
                name: 'Updated Name'
              }
            }
          }
        end

        run_test!
      end
    end

    delete 'Delete a person' do
      tags 'People'
      produces 'application/vnd.api+json'
      description 'Delete a person profile. Requires delete_person permission.'
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

      response '404', 'person not found or not accessible' do
        let(:id) { person.id }
        let(:Authorization) { "Bearer #{token}" }
        let(:Accept) { 'application/vnd.api+json' }

        run_test!
      end
    end
  end
end
