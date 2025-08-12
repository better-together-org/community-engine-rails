# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Hubs', type: :request do
  include BetterTogether::DeviseSessionHelpers

  before do
    configure_host_platform
    post better_together.user_session_path, params: {
      user: { email: 'manager@example.test', password: 'password12345' }
    }
  end

  describe 'GET /index' do
    it 'returns http success' do
      get '/en/hub'
      expect(response).to have_http_status(:ok)
    end
  end
end
