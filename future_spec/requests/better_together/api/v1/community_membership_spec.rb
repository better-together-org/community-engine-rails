# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'bt/api/v1/community_memberships_controller', type: :request do # rubocop:todo Metrics/BlockLength
  let(:user) { create(:user, :confirmed) }

  path '/bt/api/v1/community_memberships' do # rubocop:todo Metrics/BlockLength
    post 'Create a community_membership' do # rubocop:todo Metrics/BlockLength
      tags 'Community Memberships'
      consumes 'application/vnd.api+json'
      parameter name: :community_membership, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string }
        },
        required: %w[name description]
      }

      before do
        login(user)
      end

      response '403', 'forbidden' do # rubocop:todo Metrics/BlockLength
        let(:member) { create(:person) }
        let(:community) { create(:community) }
        let(:role) { create(:role) }
        let(:community_membership) do
          {
            data: {
              type: 'community_memberships',
              relationships: {
                member: {
                  data: {
                    type: 'people',
                    id: member.id
                  }
                },
                community: {
                  data: {
                    type: 'communities',
                    id: community.id
                  }
                },
                role: {
                  data: {
                    type: 'roles',
                    id: role.id
                  }
                }
              }
            }
          }
        end
        run_test!
      end

      # response '500', 'invalid request' do
      #   let(:member) { create(:person) }
      #   let(:community_membership) {
      #     {
      #       data: {
      #         type: 'community_memberships',
      #         relationships: {
      #           member: {
      #             data: {
      #               type: 'people',
      #               id: member.id
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
