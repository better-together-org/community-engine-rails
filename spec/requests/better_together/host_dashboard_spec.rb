# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'HostDashboard', type: :request do
  describe 'GET /host/host_dashboard' do
    let(:user) { create(:user, :confirmed, :platform_manager) }

    before do
      sign_in user
    end

    it 'renders recent resources for each resource group' do
      community = create(:community)
      block = create(:content_block_base)
      country = create(:geography_country)

      get better_together_host_dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(community.to_s)
      expect(response.body).to include(block.to_s)
      expect(response.body).to include(country.to_s)
    end
  end
end
