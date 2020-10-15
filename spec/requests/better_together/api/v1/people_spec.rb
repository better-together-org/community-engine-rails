require 'swagger_helper'

RSpec.describe 'bt/api/v1/people_controller', type: :request do
  path '/bt/api/v1/people' do
    post 'Create a person' do
      tags 'People'
      consumes 'application/vnd.api+json'
      parameter name: :person, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
        },
        required: ['name'],
      }

      response '201', 'person created' do
        let(:person) { { name: 'Rob' } }
        run_test!
      end

      response '422', 'invalid request' do
        let(:person) { { patient_id: 10 } }
        run_test!
      end
    end
  end
end

# resource 'People' do
#   get '/bt/api/v1/people' do
#     example 'Listing people' do
#       do_request

#       expect(status).to eq 200
#     end
#   end
# end