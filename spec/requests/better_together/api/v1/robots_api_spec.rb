# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Robots', :no_auth do
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:platform_manager_token) { api_sign_in_and_get_token(platform_manager_user) }
  let(:platform_manager_headers) { api_auth_headers(platform_manager_user, token: platform_manager_token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }

  describe 'POST /api/v1/robots' do
    it 'creates a robot record through JSON:API' do
      expect do
        post '/api/v1/robots',
             params: {
               data: {
                 type: 'robots',
                 attributes: {
                   name: 'BTS Robot',
                   identifier: 'bts_robot',
                   provider: 'openai',
                   robot_type: 'automation',
                   active: true,
                   platform_id: BetterTogether::Platform.find_by(host: true)&.id
                 }
               }
             }.to_json,
             headers: platform_manager_headers.merge(jsonapi_headers)
      end.to change(BetterTogether::Robot, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(BetterTogether::Robot.order(created_at: :desc).first.identifier).to eq('bts_robot')
    end
  end

  describe 'GET /api/v1/robots?filter[identifier]=...' do
    let!(:robot) { create(:better_together_robot, identifier: 'bts_robot', platform: BetterTogether::Platform.find_by(host: true)) }

    it 'filters robots by identifier' do
      get '/api/v1/robots', params: { filter: { identifier: robot.identifier } }, headers: platform_manager_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.fetch('data').map { |record| record.fetch('id') }).to eq([robot.id])
    end
  end
end
