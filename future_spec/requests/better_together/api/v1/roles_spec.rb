require 'swagger_helper'

RSpec.describe 'bt/api/v1/roles_controller', type: :request do
  let(:user) { create(:user, :confirmed) }

  path '/bt/api/v1/roles' do
    post 'Create a role' do
      tags 'Roles'
      consumes 'application/vnd.api+json'
      parameter name: :role, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
        },
        required: ['name', 'description'],
      }

      before do
        login(user)
      end

      response '403', 'forbidden' do
        let(:role) {
          {
            data: {
              type: 'roles',
              attributes: {
                name: 'Member',
                description: 'Belongs to something'
              }
            }
          }
        }

        run_test!
      end

      # response '422', 'invalid request' do
      #   let(:role) {
      #     {
      #       data: {
      #         type: 'roles',
      #         attributes: {
      #           name: '',
      #           description: 'Belongs to something'
      #         }
      #       }
      #     }
      #   }
      #   run_test!
      # end
    end
  end
end
