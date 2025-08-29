# frozen_string_literal: true

require 'rails_helper'

describe BetterTogether::SessionsController do # rubocop:todo RSpec/SpecFilePathFormat
  let(:user) { create(:user, :confirmed) }
  let(:login_url) { better_together.user_session_path }
  let(:logout_url) { better_together.destroy_user_session_path }

  context 'When logging in' do # rubocop:todo RSpec/ContextWording
    before do
      login('manager@example.test', 'password12345')
    end

    it 'returns a token' do
      expect(response.headers['Authorization']).to be_present
    end

    it 'returns 200' do
      expect(response).to have_http_status(:ok)
    end
  end

  context 'When password is missing' do # rubocop:todo RSpec/ContextWording
    before do
      post login_url, params: {
        user: {
          email: user.email,
          password: nil
        }
      }
    end

    it 'returns 401' do
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'When logging out' do # rubocop:todo RSpec/ContextWording
    it 'returns 200' do
      delete logout_url

      expect(response).to have_http_status(:ok)
    end
  end
end
