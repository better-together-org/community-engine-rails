# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Hubs', type: :request do
  include BetterTogether::DeviseSessionHelpers

  before do
    configure_host_platform
  end

  describe 'GET /index' do
    it 'returns http success' do
      # get '/hub/index'
      # expect(response).to have_http_status(:success)
    end
  end
end
