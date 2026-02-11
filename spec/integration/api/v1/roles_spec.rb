# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 - Roles', :skip_host_setup do
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

  path '/api/v1/roles' do
    get 'List all roles' do
      tags 'Roles'
      produces 'application/vnd.api+json'
      description 'Retrieve a list of roles. Requires authentication. Results are filtered based on user permissions.'
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

      response '200', 'roles list retrieved' do
        let!(:platform_role) do
          BetterTogether::Role.find_or_create_by!(identifier: 'platform_manager') do |role|
            role.name = 'Platform Manager'
            role.resource_type = 'BetterTogether::Platform'
            role.protected = true
          end
        end
        let!(:community_role) do
          BetterTogether::Role.find_or_create_by!(identifier: 'community_member') do |role|
            role.name = 'Community Member'
            role.resource_type = 'BetterTogether::Community'
            role.protected = true
          end
        end
        let(:Authorization) { "Bearer #{platform_manager_token}" }
        let(:Accept) { 'application/vnd.api+json' }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       type: { type: :string, example: 'roles' },
                       id: { type: :string, format: :uuid },
                       attributes: {
                         type: :object,
                         properties: {
                           name: { type: :string },
                           identifier: { type: :string },
                           resource_type: { type: :string, description: 'Class name of resource this role applies to' },
                           protected: { type: :boolean, description: 'Whether this is a system role that cannot be deleted' }
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

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:Accept) { 'application/vnd.api+json' }

        run_test!
      end
    end
  end

  path '/api/v1/roles/{id}' do
    parameter name: :id,
              in: :path,
              type: :string,
              format: :uuid,
              description: 'Role ID'

    get 'Get a specific role' do
      tags 'Roles'
      produces 'application/vnd.api+json'
      description 'Retrieve a specific role by ID. Requires authentication. Access is filtered by user permissions.'
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

      response '200', 'role found' do
        let!(:platform_role) do
          BetterTogether::Role.find_or_create_by!(identifier: 'platform_manager') do |r|
            r.name = 'Platform Manager'
            r.resource_type = 'BetterTogether::Platform'
            r.protected = true
          end
        end
        let(:id) { platform_role.id }
        let(:Authorization) { "Bearer #{platform_manager_token}" }
        let(:Accept) { 'application/vnd.api+json' }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     type: { type: :string, example: 'roles' },
                     id: { type: :string, format: :uuid },
                     attributes: {
                       type: :object,
                       properties: {
                         name: { type: :string },
                         identifier: { type: :string },
                         resource_type: { type: :string },
                         protected: { type: :boolean }
                       }
                     }
                   }
                 }
               },
               required: ['data']

        run_test!
      end

      response '401', 'unauthorized' do
        let!(:test_role) do
          BetterTogether::Role.find_or_create_by!(identifier: 'community_member') do |r|
            r.name = 'Community Member'
            r.resource_type = 'BetterTogether::Community'
            r.protected = true
          end
        end
        let(:id) { test_role.id }
        let(:Authorization) { nil }
        let(:Accept) { 'application/vnd.api+json' }

        run_test!
      end
    end

  end
end
