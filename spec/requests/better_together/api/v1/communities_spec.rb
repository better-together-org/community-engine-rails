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
        required: ['name', 'description'],
      }

      response '201', 'community created' do
        let(:creator) { create(:person) }
        let(:community) {
          {
            data: {
              type: 'communities',
              attributes: {
                name: 'Comunity 1',
                description: 'A nice community'
              },
              relationships: {
                creator: {
                  data: {
                    type: 'people',
                    id: creator.id
                  }
                }
              }
            }
          }
        }
        run_test!
      end

      response '422', 'invalid request' do
        let(:creator) { create(:person) }
        let(:community) {
          {
            data: {
              type: 'communities',
              attributes: {
                name: '',
                description: 'A nice community'
              },
              relationships: {
                creator: {
                  data: {
                    type: 'people',
                    id: creator.id
                  }
                }
              }
            }
          }
        }
        run_test!
      end
    end
  end
end
