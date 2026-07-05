# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Content Blocks Resource Search' do
  describe 'GET /content/blocks/resource_search' do
    # :as_platform_manager is scoped to just the contexts that need it (rather than
    # tagged on the top-level describe) because RSpec example metadata is inherited
    # from parent groups and merged, not overridden — a nested `:as_user`/`:no_auth`
    # context can't unset a truthy :as_platform_manager set higher up. Tagging the
    # whole file would make every example (including "not authenticated" and "not
    # authorized" below) authenticate as a platform manager regardless of its own tag.
    context 'with valid resource_class', :as_platform_manager do
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

    context 'with invalid resource_class', :as_platform_manager do
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
        # This route lives under config/routes.rb's
        # `authenticated :user, ->(u) { u.permitted_to?('manage_platform') }` scope,
        # which gates at the routing layer: the route simply doesn't match unless
        # the visitor is signed in AND a platform manager, so an unauthenticated
        # request 404s rather than redirecting to sign-in (there's no controller
        # action to redirect from). Same convention as
        # spec/requests/better_together/navigation_areas_controller_spec.rb, which
        # is nested under the identical route scope.
        get better_together.resource_search_content_blocks_path(
          resource_class: 'BetterTogether::Community',
          locale: I18n.default_locale
        )

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not authorized', :as_user do
      it 'returns not found status' do
        # Same routing-layer gate as above: a signed-in non-manager also fails the
        # `authenticated :user, ->(u) { u.permitted_to?('manage_platform') }` match,
        # so the route 404s instead of reaching the controller's `authorize` call
        # (which would otherwise be the source of a 403).
        get better_together.resource_search_content_blocks_path(
          resource_class: 'BetterTogether::Community',
          locale: I18n.default_locale
        )

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
