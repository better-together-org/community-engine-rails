# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pages filtering and sorting', :as_platform_manager, type: :request do
  let(:page1) { create(:better_together_page, title: 'Alpha Page', slug: 'alpha-page', status: 'published') }
  let(:page2) { create(:better_together_page, title: 'Beta Page', slug: 'beta-page', status: 'draft') }
  let(:page3) { create(:better_together_page, title: 'Gamma Page', slug: 'gamma-page', status: 'published') }

  before do
    page1
    page2
    page3
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

    it 'sorts by title ascending' do
      get better_together.pages_path(sort_by: 'title', sort_direction: 'asc')

      expect(response).to have_http_status(:success)
      # Check that Alpha comes before Beta in the response
      alpha_position = response.body.index('Alpha Page')
      beta_position = response.body.index('Beta Page')
      expect(alpha_position).to be < beta_position
    end

    it 'sorts by title descending' do
      get better_together.pages_path(sort_by: 'title', sort_direction: 'desc')

      expect(response).to have_http_status(:success)
      # Check that Gamma comes before Alpha in the response
      gamma_position = response.body.index('Gamma Page')
      alpha_position = response.body.index('Alpha Page')
      expect(gamma_position).to be < alpha_position
    end

    it 'sorts by status' do
      get better_together.pages_path(sort_by: 'status', sort_direction: 'asc')

      expect(response).to have_http_status(:success)
      # Draft should come before published
      draft_position = response.body.index('Beta Page') # draft status
      published_position = response.body.index('Alpha Page') # published status
      expect(draft_position).to be < published_position
    end

    it 'combines filtering and sorting' do
      get better_together.pages_path(
        title_filter: 'Page',
        sort_by: 'title',
        sort_direction: 'desc'
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Alpha Page')
      expect(response.body).to include('Beta Page')
      expect(response.body).to include('Gamma Page')
    end
  end
end
