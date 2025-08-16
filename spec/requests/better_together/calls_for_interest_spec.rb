# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CallsForInterests', type: :request do
  include BetterTogether::DeviseSessionHelpers

  before do
    configure_host_platform
  end

  describe 'GET /index' do
    it 'returns http success' do
      get '/en/calls_for_interest'
      expect(response).to have_http_status(:ok)
    end
  end
end
