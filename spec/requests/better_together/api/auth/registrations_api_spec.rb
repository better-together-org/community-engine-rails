# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::Auth::Registrations', type: :request do
  describe 'POST /api/auth/sign-up' do
    let(:url) { '/api/auth/sign-up' }
    let(:valid_params) do
      {
        user: {
          email: 'newuser@example.com',
          password: 'SecureTest123!@#',
          password_confirmation: 'SecureTest123!@#'
        },
        privacy_policy_agreement: '1',
        terms_of_service_agreement: '1',
        code_of_conduct_agreement: '1'
      }
    end

    context 'with valid parameters' do
      it 'creates a new user' do
        expect do
          post url, params: valid_params, as: :json
        end.to change(BetterTogether::User, :count).by(1)
      end

      it 'creates an associated person' do
        expect do
          post url, params: valid_params, as: :json
        end.to change(BetterTogether::Person, :count).by(1)
      end

      it 'returns created status' do
        post url, params: valid_params, as: :json
        expect(response).to have_http_status(:created)
      end

      it 'returns JSONAPI-formatted user data' do
        post url, params: valid_params, as: :json
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']['type']).to eq('users')
        expect(json['data']['attributes']).to include('email' => 'newuser@example.com')
      end

      it 'does not expose password fields' do
        post url, params: valid_params, as: :json
        json = JSON.parse(response.body)

        expect(json['data']['attributes']).not_to have_key('password')
        expect(json['data']['attributes']).not_to have_key('password_confirmation')
        expect(json['data']['attributes']).not_to have_key('encrypted_password')
      end

      it 'sends a confirmation email' do
        expect do
          post url, params: valid_params, as: :json
        end.to change { ActionMailer::Base.deliveries.count }.by(1)

        email = ActionMailer::Base.deliveries.last
        expect(email.to).to include('newuser@example.com')
        expect(email.subject).to include('Confirmation')
      end
    end

    context 'with missing email' do
      it 'returns unprocessable entity status' do
        post url, params: {
          user: {
            password: 'SecureTest123!@#',
            password_confirmation: 'SecureTest123!@#'
          }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not create a user' do
        expect do
          post url, params: {
            user: {
              password: 'SecureTest123!@#',
              password_confirmation: 'SecureTest123!@#'
            }
          }, as: :json
        end.not_to change(BetterTogether::User, :count)
      end
    end

    context 'with invalid email format' do
      it 'returns unprocessable entity status' do
        post url, params: {
          user: {
            email: 'not-an-email',
            password: 'SecureTest123!@#',
            password_confirmation: 'SecureTest123!@#'
          }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'with duplicate email' do
      let!(:existing_user) { create(:better_together_user, email: 'existing@example.com') }

      it 'returns unprocessable entity status' do
        post url, params: {
          user: {
            email: 'existing@example.com',
            password: 'SecureTest123!@#',
            password_confirmation: 'SecureTest123!@#'
          }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not create a new user' do
        expect do
          post url, params: {
            user: {
              email: 'existing@example.com',
              password: 'SecureTest123!@#',
              password_confirmation: 'SecureTest123!@#'
            }
          }, as: :json
        end.not_to change(BetterTogether::User, :count)
      end
    end

    context 'with weak password' do
      it 'returns unprocessable entity status' do
        post url, params: {
          user: {
            email: 'newuser@example.com',
            password: '12345',
            password_confirmation: '12345'
          }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'with mismatched passwords' do
      it 'returns unprocessable entity status' do
        post url, params: {
          user: {
            email: 'newuser@example.com',
            password: 'SecureTest123!@#',
            password_confirmation: 'DifferentSecure!'
          }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
