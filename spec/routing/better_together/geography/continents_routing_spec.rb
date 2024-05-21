require "rails_helper"

module BetterTogether
  RSpec.describe Geography::ContinentsController, type: :routing do
    describe "routing" do
      it "routes to #index" do
        expect(get: "/geography/continents").to route_to("geography/continents#index")
      end

      it "routes to #new" do
        expect(get: "/geography/continents/new").to route_to("geography/continents#new")
      end

      it "routes to #show" do
        expect(get: "/geography/continents/1").to route_to("geography/continents#show", id: "1")
      end

      it "routes to #edit" do
        expect(get: "/geography/continents/1/edit").to route_to("geography/continents#edit", id: "1")
      end


      it "routes to #create" do
        expect(post: "/geography/continents").to route_to("geography/continents#create")
      end

      it "routes to #update via PUT" do
        expect(put: "/geography/continents/1").to route_to("geography/continents#update", id: "1")
      end

      it "routes to #update via PATCH" do
        expect(patch: "/geography/continents/1").to route_to("geography/continents#update", id: "1")
      end

      it "routes to #destroy" do
        expect(delete: "/geography/continents/1").to route_to("geography/continents#destroy", id: "1")
      end
    end
  end
end
