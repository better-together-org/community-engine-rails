require "rails_helper"

module BetterTogether
  RSpec.describe ::BetterTogether::Geography::SettlementsController, type: :routing do
    describe "routing" do
      it "routes to #index" do
        # expect(get: "/geography/settlements").to route_to("geography/settlements#index")
      end

      it "routes to #new" do
        # expect(get: "/geography/settlements/new").to route_to("geography/settlements#new")
      end

      it "routes to #show" do
        # expect(get: "/geography/settlements/1").to route_to("geography/settlements#show", id: "1")
      end

      it "routes to #edit" do
        # expect(get: "/geography/settlements/1/edit").to route_to("geography/settlements#edit", id: "1")
      end


      it "routes to #create" do
        # expect(post: "/geography/settlements").to route_to("geography/settlements#create")
      end

      it "routes to #update via PUT" do
        # expect(put: "/geography/settlements/1").to route_to("geography/settlements#update", id: "1")
      end

      it "routes to #update via PATCH" do
        # expect(patch: "/geography/settlements/1").to route_to("geography/settlements#update", id: "1")
      end

      it "routes to #destroy" do
        # expect(delete: "/geography/settlements/1").to route_to("geography/settlements#destroy", id: "1")
      end
    end
  end
end
