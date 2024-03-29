# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'bt/api/v1/people_controller', type: :request do # rubocop:todo Metrics/BlockLength
  let(:user) { create(:user, :confirmed) }

  path '/bt/api/v1/people' do # rubocop:todo Metrics/BlockLength
    post 'Create a person' do # rubocop:todo Metrics/BlockLength
      tags 'People'
      consumes 'application/vnd.api+json'
      parameter name: :person, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string }
        },
        required: %w[name description]
      }

      before do
        login(user)
      end

      response '403', 'forbidden' do
        let(:person) do
          {
            data: {
              type: 'people',
              attributes: {
                name: 'Johnny',
                description: 'A nice guy'
              }
            }
          }
        end

        run_test!
      end

      # response '422', 'invalid request' do
      #   let(:person) {
      #     {
      #       data: {
      #         type: 'people',
      #         attributes: {
      #           name: '',
      #           description: 'A nice guy'
      #         }
      #       }
      #     }
      #   }
      #   run_test!
      # end
    end
  end
end
