# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::PersonBlocks', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }
  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }
  let(:other_person) { create(:better_together_person) }

  describe 'GET /api/v1/person_blocks' do
    let(:url) { '/api/v1/person_blocks' }
    let!(:own_block) { create(:person_block, blocker: person, blocked: other_person) }
    let!(:other_block) { create(:person_block) }

    context 'when authenticated' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted data' do
        json = JSON.parse(response.body)
        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)
      end

      it 'returns only own blocks' do
        json = JSON.parse(response.body)
        block_ids = json['data'].map { |b| b['id'] }

        expect(block_ids).to include(own_block.id)
        expect(block_ids).not_to include(other_block.id)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/person_blocks/:id' do
    let!(:block) { create(:person_block, blocker: person, blocked: other_person) }
    let(:url) { "/api/v1/person_blocks/#{block.id}" }

    context 'when authenticated as blocker' do
      before { get url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSONAPI-formatted data' do
        json = JSON.parse(response.body)
        expect(json).to have_key('data')
        expect(json['data']['id']).to eq(block.id)
      end
    end
  end

  describe 'POST /api/v1/person_blocks' do
    let(:url) { '/api/v1/person_blocks' }
    let(:target_person) { create(:better_together_person, privacy: 'public') }

    let(:valid_params) do
      {
        data: {
          type: 'person_blocks',
          attributes: {
            blocked_id: target_person.id
          }
        }
      }
    end

    context 'when authenticated' do
      it 'creates a block' do
        post url, params: valid_params.to_json, headers: auth_headers
        json = JSON.parse(response.body)
        expect(response).to have_http_status(:created), -> { "Expected 201 but got #{response.status}: #{json}" }
        expect(BetterTogether::PersonBlock.where(blocker: person, blocked: target_person)).to exist
      end
    end
  end

  describe 'DELETE /api/v1/person_blocks/:id' do
    let!(:block) { create(:person_block, blocker: person, blocked: other_person) }
    let(:url) { "/api/v1/person_blocks/#{block.id}" }

    context 'when authenticated as blocker' do
      it 'deletes the block' do
        expect do
          delete url, headers: auth_headers
        end.to change(BetterTogether::PersonBlock, :count).by(-1)
      end
    end
  end
end
