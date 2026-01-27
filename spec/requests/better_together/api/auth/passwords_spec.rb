# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::Auth::Passwords', type: :request do
  let(:user) { create(:better_together_user, :confirmed, password: 'SecureTest123!@#', password_confirmation: 'SecureTest123!@#') }

  describe 'POST /api/auth/password' do
    let(:url) { '/api/auth/password' }

    context 'when requesting password reset' do
      context 'with valid email' do
        before do
          post url, params: { user: { email: user.email } }, as: :json
        end

        it 'returns success status' do
          expect(response).to have_http_status(:ok)
        end

        it 'sends password reset email' do
          expect(ActionMailer::Base.deliveries.count).to be > 0
        end
      end

      context 'with non-existent email' do
        before do
          post url, params: { user: { email: 'nonexistent@example.com' } }, as: :json
        end

        it 'returns success status to prevent email enumeration' do
          expect(response).to have_http_status(:ok)
        end
      end

      context 'with missing email' do
        before do
          post url, params: { user: { email: '' } }, as: :json
        end

        it 'returns unprocessable entity status' do
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end
  end

  describe 'PUT /api/auth/password' do
    let(:url) { '/api/auth/password' }
    let(:reset_token) { user.send_reset_password_instructions }

    context 'when resetting password with valid token' do
      before do
        put url, params: {
          user: {
            reset_password_token: reset_token,
            password: 'NewSecure456!@#',
            password_confirmation: 'NewSecure456!@#'
          }
        }, as: :json
      end

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'resets the password' do
        expect(user.reload.valid_password?('NewSecure456!@#')).to be true
      end

      it 'does not expose password in response' do
        json = JSON.parse(response.body)
        expect(json.to_s).not_to include('NewSecure456!@#')
      end
    end

    context 'with invalid token' do
      before do
        put url, params: {
          user: {
            reset_password_token: 'invalid_token',
            password: 'NewSecure456!@#',
            password_confirmation: 'NewSecure456!@#'
          }
        }, as: :json
      end

      it 'returns unprocessable entity status' do
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'with mismatched passwords' do
      before do
        put url, params: {
          user: {
            reset_password_token: reset_token,
            password: 'NewSecure456!@#',
            password_confirmation: 'DifferentPass!'
          }
        }, as: :json
      end

      it 'returns unprocessable entity status' do
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'with weak password' do
      before do
        put url, params: {
          user: {
            reset_password_token: reset_token,
            password: '12345',
            password_confirmation: '12345'
          }
        }, as: :json
      end

      it 'returns unprocessable entity status' do
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
