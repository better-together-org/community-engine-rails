# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::PersonDataExports', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:headers) { api_auth_headers(user, token: token) }

  it 'lists current user exports' do
    create(:better_together_person_data_export, person: user.person)

    get '/api/v1/me/data_exports', headers: headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['data'].length).to eq(1)
  end

  it 'creates a new export' do
    expect do
      post '/api/v1/me/data_exports', headers: headers
    end.to change(BetterTogether::PersonDataExport, :count).by(1)

    expect(response).to have_http_status(:created)
  end
end
