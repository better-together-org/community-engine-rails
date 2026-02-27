# frozen_string_literal: true

require 'swagger_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'People API', type: :request, no_auth: true do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:Authorization) { "Bearer #{api_sign_in_and_get_token(user)}" }

  path '/api/v1/people/me' do
    get 'Get current user profile' do
      tags 'People'
      security [bearer_auth: []]
      produces 'application/vnd.api+json'
      description "Retrieve the authenticated user's person profile."

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'current person retrieved' do
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
               }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid' }
        run_test!
      end
    end
  end

  path '/api/v1/people' do
    get 'List people' do
      tags 'People'
      security [bearer_auth: []]
      produces 'application/vnd.api+json'
      description 'List people. Returns public profiles for all, own profile always included.'

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :'page[number]', in: :query, type: :integer, required: false
      parameter name: :'page[size]', in: :query, type: :integer, required: false

      response '200', 'people listed' do
        run_test!
      end
    end
  end

  path '/api/v1/people/{id}' do
    parameter name: :id, in: :path, type: :string, format: :uuid, required: true

    let!(:person) { create(:better_together_person, privacy: 'public') }
    let(:id) { person.id }

    get 'Get a person' do
      tags 'People'
      security [bearer_auth: []]
      produces 'application/vnd.api+json'
      description 'Get a person by ID. Respects privacy settings.'

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'person found' do
        run_test!
      end

      response '404', 'not found or private' do
        let(:id) { SecureRandom.uuid }
        run_test!
      end
    end
  end
end

RSpec.describe 'Roles API (read-only)', type: :request, no_auth: true do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:Authorization) { "Bearer #{api_sign_in_and_get_token(user)}" }

  path '/api/v1/roles' do
    get 'List roles' do
      tags 'Roles'
      security [bearer_auth: []]
      produces 'application/vnd.api+json'
      description 'List all platform roles.'

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'roles listed' do
        run_test!
      end
    end
  end

  path '/api/v1/roles/{id}' do
    parameter name: :id, in: :path, type: :string, format: :uuid, required: true

    let!(:role) { BetterTogether::Role.first || create(:better_together_role) }
    let(:id) { role.id }

    get 'Get a role' do
      tags 'Roles'
      security [bearer_auth: []]
      produces 'application/vnd.api+json'

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'role found' do
        run_test!
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
