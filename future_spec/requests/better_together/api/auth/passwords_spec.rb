# frozen_string_literal: true

require 'rails_helper'

describe BetterTogether::SessionsController, type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:login_url) { better_together.user_session_path }
  let(:logout_url) { better_together.destroy_user_session_path }

  context 'When logging in' do
    before do
      login('manager@example.test', 'password12345')
    end

    it 'returns a token' do
      expect(response.headers['Authorization']).to be_present
    end

    it 'returns 200' do
      expect(response.status).to eq(200)
    end
  end

  context 'When password is missing' do
    before do
      post login_url, params: {
        user: {
          email: user.email,
          password: nil
        }
      }
    end

    it 'returns 401' do
      expect(response.status).to eq(401)
    end
  end

  context 'When logging out' do
    it 'returns 200' do
      delete logout_url

      expect(response).to have_http_status(:ok)
    end
  end
end
