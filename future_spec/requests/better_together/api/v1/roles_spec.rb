# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'bt/api/v1/roles_controller', type: :request do # rubocop:todo Metrics/BlockLength
  let(:user) { create(:user, :confirmed) }

  path '/bt/api/v1/roles' do # rubocop:todo Metrics/BlockLength
    post 'Create a role' do # rubocop:todo Metrics/BlockLength
      tags 'Roles'
      consumes 'application/vnd.api+json'
      parameter name: :role, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string }
        },
        required: %w[name description]
      }

      before do
        login('manager@example.test', 'password12345')
      end

      response '403', 'forbidden' do
        let(:role) do
          {
            data: {
              type: 'roles',
              attributes: {
                name: 'Member',
                description: 'Belongs to something'
              }
            }
          }
        end

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
