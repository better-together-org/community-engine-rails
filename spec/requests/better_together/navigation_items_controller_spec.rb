# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::NavigationItemsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:user) { create(:better_together_user, :confirmed, :platform_manager) }
  let!(:navigation_area) { create(:better_together_navigation_area) }

  describe 'GET /:locale/.../navigation_areas/:navigation_area_id/navigation_items' do
    it 'returns ok for index' do
      get better_together.navigation_area_navigation_items_path(
        locale:,
        navigation_area_id: navigation_area.slug
      )

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /:locale/.../navigation_areas/:navigation_area_id/navigation_items' do
    let(:params) do
      # Start with factory attributes, then adapt to permitted keys
      raw_attrs = attributes_for(:better_together_navigation_item)
      permitted = raw_attrs.slice(:url, :icon, :position, :visible, :item_type, :parent_id, :route_name)
      # Use localized title key instead of :title; drop non-permitted keys (:slug, :id, :linkable_*)
      permitted["title_#{locale}"] = raw_attrs[:title]

      { navigation_item: permitted }
    end

    # rubocop:todo RSpec/MultipleExpectations
    it 'creates a navigation item and redirects (HTML), persisting permitted fields' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      post better_together.navigation_area_navigation_items_path(
        locale:,
        navigation_area_id: navigation_area.slug
      ), params: params

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response).to have_http_status(:ok)

      # Verify attributes were persisted via strong params
      created = BetterTogether::NavigationItem.order(:created_at).last
      expect(created).to be_present
      expect(created.navigation_area_id).to eq(navigation_area.id)
      expect(created.title(locale:)).to eq(params[:navigation_item]["title_#{locale}"])
      expect(created.url).to eq(params[:navigation_item][:url])
      expect(created.visible).to eq(params[:navigation_item][:visible])
      expect(created.item_type).to eq(params[:navigation_item][:item_type])
    end

    it 'renders errors on invalid params' do
      post better_together.navigation_area_navigation_items_path(
        locale:,
        navigation_area_id: navigation_area.slug
      ), params: { navigation_item: { "title_#{locale}": '' } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'GET/PUT/DELETE on a navigation item' do
    let!(:item) { create(:better_together_navigation_item, navigation_area: navigation_area, protected: false) }

    it 'shows the item' do
      get better_together.navigation_area_navigation_item_path(locale:, navigation_area_id: navigation_area.slug,
                                                               id: item.slug)
      expect(response).to have_http_status(:ok)
    end

    # rubocop:todo RSpec/MultipleExpectations
    it 'updates with valid params then redirects and applies changes' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      put better_together.navigation_area_navigation_item_path(
        locale:,
        navigation_area_id: navigation_area.slug,
        id: item.slug
      ), params: { navigation_item: { "title_#{locale}": 'Updated Title' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response).to have_http_status(:ok)

      expect(item.reload.title(locale:)).to eq('Updated Title')
    end

    it 'renders edit on invalid params (422)' do
      put better_together.navigation_area_navigation_item_path(
        locale:,
        navigation_area_id: navigation_area.slug,
        id: item.slug
      ), params: { navigation_item: { "title_#{locale}": '' } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    # rubocop:todo RSpec/MultipleExpectations
    it 'destroys and redirects' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      delete better_together.navigation_area_navigation_item_path(
        locale:,
        navigation_area_id: navigation_area.slug,
        id: item.slug
      )
      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end
end
