require 'swagger_helper'

RSpec.describe 'bt/api/v1/communities_controller', type: :request do
  path '/bt/api/v1/communities' do
    post 'Create a community' do
      tags 'Communities'
      consumes 'application/vnd.api+json'
      parameter name: :community, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
        },
        required: ['name'],
      }

      response '201', 'community created' do
        let(:community) { { name: 'Comunity 1' } }
        run_test!
      end

      response '422', 'invalid request' do
        let(:community) { { patient_id: 10 } }
        run_test!
      end
    end
  end
end
