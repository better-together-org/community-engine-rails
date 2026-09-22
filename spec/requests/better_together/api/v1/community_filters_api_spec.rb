# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::Community filters', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }

  describe 'GET /api/v1/communities?filter[slug]=...' do
    let!(:target_community) { create(:better_together_community, privacy: 'public', slug: 'better-together-solutions') }
    let!(:other_community) { create(:better_together_community, privacy: 'public', slug: 'other-community') }

    it 'filters communities by slug' do
      get '/api/v1/communities', params: { filter: { slug: target_community.slug } }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.fetch('data').map { |record| record.fetch('id') }).to eq([target_community.id])
    end
  end
end
