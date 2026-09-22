# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Events API', :no_auth, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:user) { create(:better_together_user, :confirmed) }
  let(:Authorization) { "Bearer #{api_sign_in_and_get_token(user)}" } # rubocop:disable RSpec/VariableName
  let!(:content_publishing_agreement) do
    BetterTogether::Agreement.find_or_create_by!(identifier: BetterTogether::PublicVisibilityGate::AGREEMENT_IDENTIFIER)
  end

  path '/api/v1/events' do
    get 'List events' do
      tags 'Events'
      security [{ bearer_auth: [] }]
      produces 'application/vnd.api+json'
      description 'List events accessible to the authenticated user.'

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :'page[number]', in: :query, type: :integer, required: false
      parameter name: :'page[size]', in: :query, type: :integer, required: false

      response '200', 'events listed' do
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid' } # rubocop:disable RSpec/VariableName
        run_test!
      end
    end

    post 'Create an event' do
      tags 'Events'
      security [{ bearer_auth: [] }]
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          data: {
            type: :object,
            properties: {
              type: { type: :string, example: 'events' },
              attributes: {
                type: :object,
                properties: {
                  name: { type: :string },
                  starts_at: { type: :string, format: :'date-time' },
                  ends_at: { type: :string, format: :'date-time' },
                  privacy: { type: :string, enum: %w[public private] }
                },
                required: %w[name]
              }
            },
            required: %w[type attributes]
          }
        },
        required: %w[data]
      }

      response '201', 'event created' do
        let(:pm_user) { create(:better_together_user, :confirmed, :platform_manager) }
        let(:Authorization) { "Bearer #{api_sign_in_and_get_token(pm_user)}" } # rubocop:disable RSpec/VariableName
        let(:body) do
          {
            data: {
              type: 'events',
              attributes: {
                name: 'Test Event',
                starts_at: 1.week.from_now.iso8601,
                ends_at: 1.week.from_now.advance(hours: 2).iso8601,
                privacy: 'public'
              }
            }
          }
        end

        before do
          create(:better_together_agreement_participant,
                 agreement: content_publishing_agreement,
                 participant: pm_user.person,
                 accepted_at: Time.current)
        end

        run_test!
      end
    end
  end

  path '/api/v1/events/{id}' do
    parameter name: :id, in: :path, type: :string, format: :uuid, required: true

    let!(:event) { create(:better_together_event, privacy: 'public') }
    let(:id) { event.id }

    get 'Get an event' do
      tags 'Events'
      security [{ bearer_auth: [] }]
      produces 'application/vnd.api+json'

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'event found' do
        run_test!
      end

      response '404', 'not found' do
        let(:id) { SecureRandom.uuid }
        run_test!
      end
    end

    patch 'Update an event' do
      tags 'Events'
      security [{ bearer_auth: [] }]
      consumes 'application/vnd.api+json'
      produces 'application/vnd.api+json'

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          data: {
            type: :object,
            properties: {
              type: { type: :string, example: 'events' },
              id: { type: :string, format: :uuid },
              attributes: { type: :object, properties: { name: { type: :string } } }
            },
            required: %w[type id attributes]
          }
        },
        required: %w[data]
      }

      response '200', 'event updated' do
        let!(:own_event) { create(:better_together_event, privacy: 'public', creator: user.person) }
        let(:id) { own_event.id }
        let(:body) { { data: { type: 'events', id: own_event.id, attributes: { name: 'Updated Event' } } } }
        run_test!
      end
    end

    delete 'Delete an event' do
      tags 'Events'
      security [{ bearer_auth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'event deleted' do
        let(:pm_user) { create(:better_together_user, :confirmed, :platform_manager) }
        let(:Authorization) { "Bearer #{api_sign_in_and_get_token(pm_user)}" } # rubocop:disable RSpec/VariableName
        let!(:own_event) { create(:better_together_event, privacy: 'public', creator: pm_user.person) }
        let(:id) { own_event.id }
        run_test!
      end
    end
  end
end
