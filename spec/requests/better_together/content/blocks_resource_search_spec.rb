# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Content Blocks Resource Search', :as_platform_manager do
  describe 'GET /content/blocks/resource_search' do
    context 'with valid resource_class' do
      it 'returns policy-scoped communities' do
        community = create(:better_together_community, name: 'Test Community', privacy: :public)
        get better_together.resource_search_content_blocks_path(
          resource_class: 'BetterTogether::Community',
          locale: I18n.default_locale
        )

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to be_an(Array)
        expect(json.first).to include('value', 'text')
        expect(json.map { |r| r['value'] }).to include(community.id.to_s)
      end

      it 'filters by search term' do
        create(:better_together_community, name: 'Matching Community', privacy: :public)
        create(:better_together_community, name: 'Other Community', privacy: :public)
        get better_together.resource_search_content_blocks_path(
          resource_class: 'BetterTogether::Community',
          search: 'Matching',
          locale: I18n.default_locale
        )

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.map { |r| r['text'] }).to all(include('Matching'))
      end
    end

    context 'with invalid resource_class' do
      it 'returns empty array and unprocessable_content status' do
        get better_together.resource_search_content_blocks_path(
          resource_class: 'NonExistentClass',
          locale: I18n.default_locale
        )

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json).to eq([])
      end
    end

    context 'when not authenticated', :no_auth do
      it 'requires authentication' do
        get better_together.resource_search_content_blocks_path(
          resource_class: 'BetterTogether::Community',
          locale: I18n.default_locale
        )

        expect(response).to have_http_status(:found)
        expect(response.location).to match(/sign_in/)
      end
    end

    context 'when not authorized', :as_user do
      it 'returns forbidden status' do
        get better_together.resource_search_content_blocks_path(
          resource_class: 'BetterTogether::Community',
          locale: I18n.default_locale
        )

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
