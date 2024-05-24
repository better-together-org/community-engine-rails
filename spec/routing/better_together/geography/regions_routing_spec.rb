# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe ::BetterTogether::Geography::RegionsController, type: :routing do
    describe 'routing' do
      it 'routes to #index' do
        # expect(get: "/geography/regions").to route_to("geography/regions#index")
      end

      it 'routes to #new' do
        # expect(get: "/geography/regions/new").to route_to("geography/regions#new")
      end

      it 'routes to #show' do
        # expect(get: "/geography/regions/1").to route_to("geography/regions#show", id: "1")
      end

      it 'routes to #edit' do
        # expect(get: "/geography/regions/1/edit").to route_to("geography/regions#edit", id: "1")
      end

      it 'routes to #create' do
        # expect(post: "/geography/regions").to route_to("geography/regions#create")
      end

      it 'routes to #update via PUT' do
        # expect(put: "/geography/regions/1").to route_to("geography/regions#update", id: "1")
      end

      it 'routes to #update via PATCH' do
        # expect(patch: "/geography/regions/1").to route_to("geography/regions#update", id: "1")
      end

      it 'routes to #destroy' do
        # expect(delete: "/geography/regions/1").to route_to("geography/regions#destroy", id: "1")
      end
    end
  end
end
