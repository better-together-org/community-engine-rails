require "rails_helper"

module BetterTogether
  RSpec.describe Geography::StatesController, type: :routing do
    describe "routing" do
      it "routes to #index" do
        expect(get: "/geography/states").to route_to("geography/states#index")
      end

      it "routes to #new" do
        expect(get: "/geography/states/new").to route_to("geography/states#new")
      end

      it "routes to #show" do
        expect(get: "/geography/states/1").to route_to("geography/states#show", id: "1")
      end

      it "routes to #edit" do
        expect(get: "/geography/states/1/edit").to route_to("geography/states#edit", id: "1")
      end


      it "routes to #create" do
        expect(post: "/geography/states").to route_to("geography/states#create")
      end

      it "routes to #update via PUT" do
        expect(put: "/geography/states/1").to route_to("geography/states#update", id: "1")
      end

      it "routes to #update via PATCH" do
        expect(patch: "/geography/states/1").to route_to("geography/states#update", id: "1")
      end

      it "routes to #destroy" do
        expect(delete: "/geography/states/1").to route_to("geography/states#destroy", id: "1")
      end
    end
  end
end
