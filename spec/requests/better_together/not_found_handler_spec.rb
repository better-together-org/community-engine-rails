# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'NotFoundHandler', type: :request do
  include BetterTogether::DeviseSessionHelpers

  before do
    configure_host_platform
    post better_together.user_session_path, params: {
      user: { email: 'manager@example.test', password: 'password12345' }
    }
  end

  describe 'pages' do
    it 'renders 404 for missing page' do
      get '/en/nonexistent-page'
      expect(response).to have_http_status(:not_found)
    end

    it 'renders promo page for root variants' do
      get '/en/home-page'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Community Engine')
    end
  end

  describe 'other resources' do
    it 'renders 404 for missing post' do
      get '/en/posts/nonexistent'
      expect(response).to have_http_status(:not_found)
    end
  end
end
