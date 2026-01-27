# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Security - Password Exposure Prevention', type: :request do
  let(:user) { create(:better_together_user, :confirmed, password: 'Password123!', password_confirmation: 'Password123!') }
  let(:person) { user.person }
  let(:token) { sign_in_and_get_token(user) }
  let(:auth_headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/vnd.api+json' } }

  describe 'Authentication endpoints' do
    context 'POST /api/auth/sign-in' do
      it 'does not expose password fields in response' do
        post '/api/auth/sign-in', params: {
          user: {
            email: user.email,
            password: 'Password123!'
          }
        }, as: :json

        json = JSON.parse(response.body)

        expect(json['data']['attributes']).not_to have_key('password')
        expect(json['data']['attributes']).not_to have_key('password_confirmation')
        expect(json['data']['attributes']).not_to have_key('encrypted_password')
        expect(json['data']['attributes']).not_to have_key('reset_password_token')
        expect(json['data']['attributes']).not_to have_key('confirmation_token')
      end
    end

    context 'POST /api/auth/sign-up' do
      it 'does not expose password fields in response' do
        post '/api/auth/sign-up', params: {
          user: {
            email: 'newuser@example.com',
            password: 'Password123!',
            password_confirmation: 'Password123!'
          }
        }, as: :json

        json = JSON.parse(response.body)

        expect(json['data']['attributes']).not_to have_key('password')
        expect(json['data']['attributes']).not_to have_key('password_confirmation')
        expect(json['data']['attributes']).not_to have_key('encrypted_password')
        expect(json['data']['attributes']).not_to have_key('reset_password_token')
        expect(json['data']['attributes']).not_to have_key('confirmation_token')
      end
    end
  end

  describe 'User resource endpoints' do
    context 'GET /api/v1/people (list)' do
      it 'does not expose password fields for any user' do
        get '/en/api/v1/people', headers: auth_headers

        json = JSON.parse(response.body)

        json['data'].each do |person_data|
          expect(person_data['attributes']).not_to have_key('password')
          expect(person_data['attributes']).not_to have_key('password_confirmation')
          expect(person_data['attributes']).not_to have_key('encrypted_password')
        end
      end
    end

    context 'GET /api/v1/people/:id (show)' do
      it 'does not expose password fields' do
        get "/en/api/v1/people/#{person.id}", headers: auth_headers

        json = JSON.parse(response.body)

        expect(json['data']['attributes']).not_to have_key('password')
        expect(json['data']['attributes']).not_to have_key('password_confirmation')
        expect(json['data']['attributes']).not_to have_key('encrypted_password')
      end
    end

    context 'GET /api/v1/people/me' do
      it 'does not expose password fields in own profile' do
        get '/en/api/v1/people/me', headers: auth_headers

        json = JSON.parse(response.body)

        expect(json['data']['attributes']).not_to have_key('password')
        expect(json['data']['attributes']).not_to have_key('password_confirmation')
        expect(json['data']['attributes']).not_to have_key('encrypted_password')
      end
    end
  end

  describe 'Error responses' do
    context 'when authentication fails' do
      it 'does not expose password-related information in error messages' do
        post '/api/auth/sign-in', params: {
          user: {
            email: user.email,
            password: 'WrongPassword!'
          }
        }, as: :json

        expect(response.body).not_to include('encrypted_password')
        expect(response.body).not_to include('password_digest')
        expect(response.body).not_to include('bcrypt')
      end
    end

    context 'when registration fails' do
      it 'does not expose password in validation errors' do
        post '/api/auth/sign-up', params: {
          user: {
            email: user.email, # Duplicate email
            password: 'Password123!',
            password_confirmation: 'Password123!'
          }
        }, as: :json

        json = JSON.parse(response.body)

        # Errors might be present, but they shouldn't include the actual password value
        if json['errors']
          json['errors'].each do |error|
            expect(error['detail']).not_to include('Password123!')
          end
        end
      end
    end
  end

  describe 'Included relationships' do
    context 'when person includes user relationship' do
      it 'does not expose password fields in included user data' do
        get "/en/api/v1/people/#{person.id}?include=user", headers: auth_headers

        json = JSON.parse(response.body)

        if json['included']
          user_data = json['included'].find { |inc| inc['type'] == 'users' }

          if user_data
            expect(user_data['attributes']).not_to have_key('password')
            expect(user_data['attributes']).not_to have_key('password_confirmation')
            expect(user_data['attributes']).not_to have_key('encrypted_password')
          end
        end
      end
    end
  end

  describe 'JWT tokens' do
    it 'does not include password information in JWT payload' do
      post '/api/auth/sign-in', params: {
        user: {
          email: user.email,
          password: 'Password123!'
        }
      }, as: :json

      token = response.headers['Authorization'].sub('Bearer ', '')
      decoded_token = JWT.decode(token, Rails.application.credentials.devise_jwt_secret_key!)[0]

      expect(decoded_token).not_to have_key('password')
      expect(decoded_token).not_to have_key('encrypted_password')
      expect(decoded_token.to_json).not_to include('Password123!')
    end
  end

  def sign_in_and_get_token(user)
    post '/api/auth/sign-in', params: {
      user: {
        email: user.email,
        password: 'Password123!'
      }
    }, as: :json

    response.headers['Authorization'].sub('Bearer ', '')
  end
end
