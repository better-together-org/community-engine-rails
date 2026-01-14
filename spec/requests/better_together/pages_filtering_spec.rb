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

  describe 'POST /host/pages' do
    let(:valid_params) do
      {
        page: {
          title: 'New Test Page',
          privacy: 'public'
        },
        locale: I18n.default_locale
      }
    end

    let(:invalid_params) do
      {
        page: {
          title: '',
          privacy: 'public'
        },
        locale: I18n.default_locale
      }
    end

    context 'with valid parameters' do
      it 'sets the creator from current_person' do
        platform_manager_user = BetterTogether::User.find_by(email: 'manager@example.test')

        post better_together.pages_path, params: valid_params

        created_page = BetterTogether::Page.last
        expect(created_page.creator).to eq(platform_manager_user.person)
      end

      it 'redirects to the edit page' do
        post better_together.pages_path, params: valid_params

        created_page = BetterTogether::Page.last
        expect(response).to redirect_to(edit_page_path(created_page))
      end

      it 'displays a success notice' do
        post better_together.pages_path, params: valid_params

        follow_redirect!
        expect_html_content(I18n.t('flash.generic.created', resource: I18n.t('resources.page')))
      end
    end

    context 'with invalid parameters' do
      it 'does not create a page' do
        expect do
          post better_together.pages_path, params: invalid_params
        end.not_to change(BetterTogether::Page, :count)
      end

      it 'renders the new template with errors' do
        post better_together.pages_path, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('can&#39;t be blank')
      end
    end

    context 'when user is not authenticated' do
      before { logout }

      it 'returns 404 because route is not available' do
        expect do
          post better_together.pages_path, params: {
            page: { title: 'Test', privacy: 'public' },
            locale: I18n.default_locale
          }
        end.to raise_error(ActionController::RoutingError, /No route matches/)
      end
    end
  end
end
