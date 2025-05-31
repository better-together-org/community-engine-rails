require 'rails_helper'

RSpec.describe "CallsForInterests", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/calls_for_interest/index"
      expect(response).to have_http_status(:success)
    end
  end

end
