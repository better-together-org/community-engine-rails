# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::Auth::Confirmations', :no_auth, type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:better_together_user, confirmed_at: nil) }
  let(:confirmation_token) { user.confirmation_token }

  describe 'POST /api/auth/confirmation' do
    let(:url) { '/api/auth/confirmation' }

    context 'when requesting a new confirmation email' do
      context 'with valid email' do
        before do
          perform_enqueued_jobs do
            post url, params: { user: { email: user.email } }, as: :json
          end
        end

        it 'returns success status' do
          expect(response).to have_http_status(:ok)
        end

        it 'sends confirmation email' do
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
    end
  end

  describe 'GET /api/auth/confirmation' do
    let(:url) { '/api/auth/confirmation' }

    context 'with valid confirmation token' do
      before do
        user.send_confirmation_instructions
        get url, params: { confirmation_token: user.reload.confirmation_token }
      end

      it 'confirms the user' do
        expect(user.reload.confirmed?).to be true
      end

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid confirmation token' do
      before do
        get url, params: { confirmation_token: 'invalid_token' }
      end

      it 'returns unprocessable entity status' do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not confirm the user' do
        expect(user.reload.confirmed?).to be false
      end
    end

    context 'with already confirmed user' do
      let(:confirmed_user) { create(:better_together_user, :confirmed) }

      before do
        confirmed_user.send_confirmation_instructions
        get url, params: { confirmation_token: confirmed_user.reload.confirmation_token }
      end

      it 'returns unprocessable entity status' do
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
