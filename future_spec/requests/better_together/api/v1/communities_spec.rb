# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'bt/api/v1/communities_controller', type: :request do # rubocop:todo Metrics/BlockLength
  let(:user) { create(:user, :confirmed) }

  path '/bt/api/v1/communities' do # rubocop:todo Metrics/BlockLength
    post 'Create a community' do # rubocop:todo Metrics/BlockLength
      tags 'Communities'
      consumes 'application/vnd.api+json'
      parameter name: :community, in: :body, schema: {
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
        let(:creator) { create(:person) }
        let(:community) do
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
        end
        run_test!
      end

      # response '422', 'invalid request' do
      #   let(:creator) { create(:person) }
      #   let(:community) {
      #     {
      #       data: {
      #         type: 'communities',
      #         attributes: {
      #           name: '',
      #           description: 'A nice community'
      #         },
      #         relationships: {
      #           creator: {
      #             data: {
      #               type: 'people',
      #               id: creator.id
      #             }
      #           }
      #         }
      #       }
      #     }
      #   }
      #   run_test!
      # end
    end
  end
end
