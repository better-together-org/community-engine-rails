# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::NavigationAreasController', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  context 'with platform manager role' do
    describe 'GET /:locale/.../navigation_areas' do
      it 'renders index' do
        get better_together.navigation_areas_path(locale:)
        expect(response).to have_http_status(:ok)
      end

      it 'renders new' do
        get better_together.new_navigation_area_path(locale:)
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'POST /:locale/.../navigation_areas' do
      # rubocop:todo RSpec/MultipleExpectations
      it 'creates and redirects on valid params, persisting permitted fields' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
        # rubocop:enable RSpec/MultipleExpectations
        post better_together.navigation_areas_path(locale:), params: {
          navigation_area: {
            name: 'Main Nav',
            visible: true,
            style: 'primary'
          }
        }

        expect(response).to have_http_status(:found)
        follow_redirect!
        expect(response).to have_http_status(:ok)

        area = BetterTogether::NavigationArea.find_by(identifier: 'main-nav')
        expect(area).to be_present
        expect(area.style).to eq('primary')
        expect(area.visible).to be(true)
      end

      it 'renders new on invalid params (HTML 200)' do
        post better_together.navigation_areas_path(locale:), params: { navigation_area: { name: '' } }
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'PATCH /:locale/.../navigation_areas/:id' do
      let!(:area) { create(:better_together_navigation_area, protected: false) }

      # rubocop:todo RSpec/MultipleExpectations
      it 'updates and redirects on valid params, applying changes' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
        # rubocop:enable RSpec/MultipleExpectations
        patch better_together.navigation_area_path(locale:, id: area.slug), params: {
          navigation_area: { style: 'secondary', visible: false }
        }
        expect(response).to have_http_status(:found)
        follow_redirect!
        expect(response).to have_http_status(:ok)

        expect(area.reload.style).to eq('secondary')
        expect(area.reload.visible).to be(false)
      end

      it 'renders edit on invalid params (HTML 200)' do
        patch better_together.navigation_area_path(locale:, id: area.slug), params: {
          navigation_area: { name: '' }
        }
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'DELETE /:locale/.../navigation_areas/:id' do
      let!(:area) { create(:better_together_navigation_area, protected: false) }

      it 'destroys and redirects' do # rubocop:todo RSpec/MultipleExpectations
        delete better_together.navigation_area_path(locale:, id: area.slug)
        expect(response).to have_http_status(:found)
        follow_redirect!
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
