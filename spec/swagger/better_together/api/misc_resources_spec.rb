# frozen_string_literal: true

require 'swagger_helper'

# rubocop:disable RSpec/DescribeClass, RSpec/MultipleDescribes
RSpec.describe 'Notifications API', :no_auth, type: :request do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:Authorization) { "Bearer #{api_sign_in_and_get_token(user)}" } # rubocop:disable RSpec/VariableName

  path '/api/v1/notifications' do
    get 'List notifications' do
      tags 'Notifications'
      security [bearer_auth: []]
      produces 'application/vnd.api+json'
      description "List the current user's notifications."

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :'page[number]', in: :query, type: :integer, required: false
      parameter name: :'page[size]', in: :query, type: :integer, required: false

      response '200', 'notifications listed' do
        run_test!
      end
    end
  end

  path '/api/v1/notifications/mark_all_read' do
    post 'Mark all notifications as read' do
      tags 'Notifications'
      security [bearer_auth: []]
      produces 'application/json'
      description 'Mark all unread notifications as read for the current user.'

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'all notifications marked read' do
        run_test!
      end
    end
  end
end

RSpec.describe 'Invitations API', :no_auth, type: :request do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:Authorization) { "Bearer #{api_sign_in_and_get_token(user)}" } # rubocop:disable RSpec/VariableName

  path '/api/v1/invitations' do
    get 'List invitations' do
      tags 'Invitations'
      security [bearer_auth: []]
      produces 'application/vnd.api+json'
      description "List the current user's community invitations."

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'invitations listed' do
        run_test!
      end
    end

    post 'Create an invitation' do
      tags 'Invitations'
      security [bearer_auth: []]
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'
      description 'Invite someone to a community. Requires manage_community permission.'

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          data: {
            type: :object,
            properties: {
              type: { type: :string, example: 'invitations' },
              attributes: {
                type: :object,
                properties: {
                  invitee_email: { type: :string, format: :email, description: 'Email of person to invite' },
                  locale: { type: :string, description: 'Preferred locale for the invitation', example: 'en' }
                },
                required: %w[invitee_email]
              }
            },
            required: %w[type attributes]
          }
        },
        required: %w[data]
      }

      response '201', 'invitation created' do
        let(:pm_user) { create(:better_together_user, :confirmed, :platform_manager) }
        let(:community) { create(:better_together_community) }
        let(:Authorization) { "Bearer #{api_sign_in_and_get_token(pm_user)}" } # rubocop:disable RSpec/VariableName
        let(:body) do
          {
            data: {
              type: 'invitations',
              attributes: {
                invitee_email: "invite-#{SecureRandom.hex(4)}@example.com",
                invitable_type: 'BetterTogether::Community',
                invitable_id: community.id
              }
            }
          }
        end
        run_test!
      end
    end
  end
end

RSpec.describe 'Pages API', :no_auth, type: :request do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:Authorization) { "Bearer #{api_sign_in_and_get_token(user)}" } # rubocop:disable RSpec/VariableName

  path '/api/v1/pages' do
    get 'List pages' do
      tags 'Pages'
      security [bearer_auth: []]
      produces 'application/vnd.api+json'
      description 'List published pages.'

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'pages listed' do
        run_test!
      end
    end
  end

  path '/api/v1/pages/{id}' do
    parameter name: :id, in: :path, type: :string, format: :uuid, required: true

    let!(:page) { create(:better_together_page) }
    let(:id) { page.id }

    get 'Get a page' do
      tags 'Pages'
      security [bearer_auth: []]
      produces 'application/vnd.api+json'

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'page found' do
        run_test!
      end
    end
  end
end

RSpec.describe 'Metrics API', :no_auth, type: :request do
  let(:pm_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:Authorization) { "Bearer #{api_sign_in_and_get_token(pm_user)}" } # rubocop:disable RSpec/VariableName

  path '/api/v1/metrics/summary' do
    get 'Get platform metrics summary' do
      tags 'Metrics'
      security [bearer_auth: []]
      produces 'application/json'
      description 'Get aggregated platform metrics. Requires manage_platform permission.'

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'metrics retrieved' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     communities: { type: :object },
                     people: { type: :object },
                     events: { type: :object },
                     posts: { type: :object }
                   }
                 }
               }
        run_test!
      end

      response '404', 'not authorized or not found' do
        let(:Authorization) { "Bearer #{api_sign_in_and_get_token(create(:better_together_user, :confirmed))}" } # rubocop:disable RSpec/VariableName
        run_test!
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass

# rubocop:enable RSpec/MultipleDescribes
