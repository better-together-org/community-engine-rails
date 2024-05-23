require "rails_helper"

module BetterTogether
  RSpec.describe Geography::RegionSettlementsController, type: :routing do
    describe "routing" do
      it "routes to #index" do
        expect(get: "/geography/region_settlements").to route_to("geography/region_settlements#index")
      end

      it "routes to #new" do
        expect(get: "/geography/region_settlements/new").to route_to("geography/region_settlements#new")
      end

      it "routes to #show" do
        expect(get: "/geography/region_settlements/1").to route_to("geography/region_settlements#show", id: "1")
      end

      it "routes to #edit" do
        expect(get: "/geography/region_settlements/1/edit").to route_to("geography/region_settlements#edit", id: "1")
      end


      it "routes to #create" do
        expect(post: "/geography/region_settlements").to route_to("geography/region_settlements#create")
      end

      it "routes to #update via PUT" do
        expect(put: "/geography/region_settlements/1").to route_to("geography/region_settlements#update", id: "1")
      end

      it "routes to #update via PATCH" do
        expect(patch: "/geography/region_settlements/1").to route_to("geography/region_settlements#update", id: "1")
      end

      it "routes to #destroy" do
        expect(delete: "/geography/region_settlements/1").to route_to("geography/region_settlements#destroy", id: "1")
      end
    end
  end
end
