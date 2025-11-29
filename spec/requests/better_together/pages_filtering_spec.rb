# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pages filtering and sorting', :as_platform_manager do
  let(:alpha) { create(:better_together_page, title: 'Alpha Page', slug: 'alpha-page') }
  let(:beta) { create(:better_together_page, title: 'Beta Page', slug: 'beta-page') }
  let(:gamma) { create(:better_together_page, title: 'Gamma Page', slug: 'gamma-page') }

  before do
    alpha
    beta
    gamma
  end

  describe 'GET /pages' do
    it 'displays all pages without filters' do
      get better_together.pages_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Alpha Page')
      expect(response.body).to include('Beta Page')
      expect(response.body).to include('Gamma Page')
    end

    it 'filters by title' do
      get better_together.pages_path(title_filter: 'Alpha')

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Alpha Page')
      expect(response.body).not_to include('Beta Page')
      expect(response.body).not_to include('Gamma Page')
    end
  end
end
