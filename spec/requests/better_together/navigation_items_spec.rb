# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'NavigationItems', type: :request do
  include BetterTogether::Engine.routes.url_helpers

  let(:navigation_area) { create(:navigation_area) }
  let(:navigation_item) { create(:navigation_item, navigation_area: navigation_area, title: 'Old Title') }

  before do
    allow_any_instance_of(BetterTogether::NavigationItemsController).to receive(:authorize)
  end

  describe 'PATCH /navigation_areas/:navigation_area_id/navigation_items/:id' do
    context 'HTML format' do
      it 'redirects on success' do
        patch navigation_area_navigation_item_path(navigation_area, navigation_item, locale: I18n.default_locale),
              params: { navigation_item: { title: 'New Title' } }

        expect(response).to redirect_to(navigation_area_path(navigation_area, locale: I18n.default_locale))
        expect(flash[:notice]).to be_present
      end

      it 'renders edit on failure' do
        patch navigation_area_navigation_item_path(navigation_area, navigation_item, locale: I18n.default_locale),
              params: { navigation_item: { title: '' } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('navigation_item_form')
      end
    end

    context 'Turbo Stream format' do
      it 'redirects on success' do
        patch navigation_area_navigation_item_path(navigation_area, navigation_item, locale: I18n.default_locale),
              params: { navigation_item: { title: 'New Title' } }, as: :turbo_stream

        expect(response).to redirect_to(navigation_area_path(navigation_area, locale: I18n.default_locale))
      end

      it 'renders turbo stream on failure' do
        patch navigation_area_navigation_item_path(navigation_area, navigation_item, locale: I18n.default_locale),
              params: { navigation_item: { title: '' } }, as: :turbo_stream

        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response.body).to include('form_errors')
      end
    end
  end
end
