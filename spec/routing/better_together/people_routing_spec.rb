# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe PeopleController, type: :routing do
    describe 'routing' do
      it 'routes to #index' do
        # expect(get: ::BetterTogether::Engine.routes.url_helpers.people_path).to route_to(
        #   locale: I18n.default_locale.to_s,
        #   controller: 'better_together/people',
        #   action: 'index'
        # )
      end

      it 'routes to #new' do
        # expect(get: ::BetterTogether::Engine.routes.url_helpers.new_person_path).to route_to(
        #   locale: I18n.default_locale.to_s,
        #   controller: 'better_together/people',
        #   action: 'new'
        # )
      end

      it 'routes to #show' do
        # expect(get: "/bt/host/people/1").to route_to("better_together/people#show", id: "1")
      end

      it 'routes to #edit' do
        # expect(get: "/bt/host/people/1/edit").to route_to("better_together/people#edit", id: "1")
      end

      it 'routes to #create' do
        # expect(post: ::BetterTogether::Engine.routes.url_helpers.people_path).to route_to(
        #   locale: I18n.default_locale.to_s,
        #   controller: 'better_together/people',
        #   action: 'create'
        # )
      end

      it 'routes to #update via PUT' do
        # expect(put: "/bt/host/people/1").to route_to("better_together/people#update", id: "1")
      end

      it 'routes to #update via PATCH' do
        # expect(patch: "/bt/host/people/1").to route_to("better_together/people#update", id: "1")
      end

      it 'routes to #destroy' do
        # expect(delete: "/bt/host/people/1").to route_to("better_together/people#destroy", id: "1")
      end
    end
  end
end
