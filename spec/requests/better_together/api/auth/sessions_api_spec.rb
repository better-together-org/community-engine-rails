# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::Auth::Sessions', :no_auth, type: :request do
  let(:user) { create(:better_together_user, :confirmed, password: 'SecureTest123!@#', password_confirmation: 'SecureTest123!@#') }
  let(:person) { user.person }

  describe 'POST /api/auth/sign-in' do
    let(:url) { '/api/auth/sign-in' }
    let(:valid_params) do
      {
        user: {
          email: user.email,
          password: 'SecureTest123!@#'
        }
      }
    end

    context 'with valid credentials' do
      before { post url, params: valid_params, as: :json }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns JWT token in Authorization header' do
        expect(response.headers['Authorization']).to be_present
        expect(response.headers['Authorization']).to start_with('Bearer ')
      end

      it 'returns JSONAPI-formatted session data' do
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to include(
          'type' => 'sessions',
          'attributes' => hash_including(
            'email' => user.email,
            'token' => be_present,
            'confirmed' => true
          )
        )
      end

      it 'includes person data in response' do
        json = JSON.parse(response.body)

        expect(json['data']['relationships']).to have_key('person')
        expect(json).to have_key('included')

        person_data = json['included'].find { |inc| inc['type'] == 'people' }
        expect(person_data).to be_present
        expect(person_data['id']).to eq(person.id)
      end

      it 'does not expose password fields' do
        json = JSON.parse(response.body)

        expect(json['data']['attributes']).not_to have_key('password')
        expect(json['data']['attributes']).not_to have_key('password_confirmation')
        expect(json['data']['attributes']).not_to have_key('encrypted_password')
      end
    end

    context 'with invalid email' do
      before do
        post url, params: { user: { email: 'wrong@example.com', password: 'SecureTest123!@#' } }, as: :json
      end

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not return a token' do
        expect(response.headers['Authorization']).to be_blank
      end
    end

    context 'with invalid password' do
      before do
        post url, params: { user: { email: user.email, password: 'WrongSecure456!@#' } }, as: :json
      end

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not return a token' do
        expect(response.headers['Authorization']).to be_blank
      end
    end

    context 'with missing password' do
      before do
        post url, params: { user: { email: user.email } }, as: :json
      end

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with unconfirmed email' do
      let(:unconfirmed_user) { create(:better_together_user, confirmed_at: nil) }

      before do
        post url, params: { user: { email: unconfirmed_user.email, password: 'SecureTest123!@#' } }, as: :json
      end

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/auth/sign-out' do
    let(:url) { '/api/auth/sign-out' }
    let(:token) { api_sign_in_and_get_token(user) }

    context 'with valid token' do
      before do
        delete url, headers: { 'Authorization' => "Bearer #{token}" }, as: :json
      end

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'revokes the token' do
        expect(BetterTogether::JwtDenylist.exists?(jti: extract_jti_from_token(token))).to be true
      end
    end

    context 'without token' do
      before do
        delete url, as: :json
      end

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with revoked token' do
      before do
        # Sign out once to revoke the token
        delete url, headers: { 'Authorization' => "Bearer #{token}" }, as: :json

        # Try to use the same token again
        delete url, headers: { 'Authorization' => "Bearer #{token}" }, as: :json
      end

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  def extract_jti_from_token(token)
    secret = ENV.fetch('DEVISE_SECRET') do
      Rails.application.credentials.devise_jwt_secret_key.presence || Rails.application.credentials.secret_key_base
    end
    JWT.decode(token, secret)[0]['jti']
  rescue JWT::DecodeError
    nil
  end
end
