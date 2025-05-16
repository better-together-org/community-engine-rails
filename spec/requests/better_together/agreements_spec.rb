require 'rails_helper'

RSpec.describe "Agreements", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/agreements/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/agreements/show"
      expect(response).to have_http_status(:success)
    end
  end

end
