# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'NotFoundHandler', :as_platform_manager do
  include RequestSpecHelper

  describe 'pages' do
    it 'renders 404 for missing page' do
      get '/en/nonexistent-page'
      expect(response).to have_http_status(:not_found)
    end

    it 'renders promo page for root variants' do # rubocop:todo RSpec/MultipleExpectations
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
