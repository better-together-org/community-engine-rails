# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe CommunitiesController, type: :routing do # rubocop:todo Metrics/BlockLength
    describe 'routing' do # rubocop:todo Metrics/BlockLength
      it 'routes to #index' do
        expect(get: ::BetterTogether::Engine.routes.url_helpers.communities_path).to route_to(
          locale: I18n.default_locale.to_s,
          controller: 'better_together/communities',
          action: 'index'
        )
      end

      it 'routes to #new' do
        expect(get: ::BetterTogether::Engine.routes.url_helpers.new_community_path).to route_to(
          locale: I18n.default_locale.to_s,
          controller: 'better_together/communities',
          action: 'new'
        )
      end

      it 'routes to #show' do
        # expect(get: "/bt/host/communities/1").to route_to("better_together/communities#show", id: "1")
      end

      it 'routes to #edit' do
        # expect(get: "/bt/host/communities/1/edit").to route_to("better_together/communities#edit", id: "1")
      end

      it 'routes to #create' do
        expect(post: ::BetterTogether::Engine.routes.url_helpers.communities_path).to route_to(
          locale: I18n.default_locale.to_s,
          controller: 'better_together/communities',
          action: 'create'
        )
      end

      it 'routes to #update via PUT' do
        # expect(put: "/bt/host/communities/1").to route_to("better_together/communities#update", id: "1")
      end

      it 'routes to #update via PATCH' do
        # expect(patch: "/bt/host/communities/1").to route_to("better_together/communities#update", id: "1")
      end

      it 'routes to #destroy' do
        # expect(delete: "/bt/host/communities/1").to route_to("better_together/communities#destroy", id: "1")
      end
    end
  end
end
