require "rails_helper"

module BetterTogether
  RSpec.describe PlatformsController, type: :routing do
    describe "routing" do
      it "routes to #index" do
        expect(get: "/platforms").to route_to("platforms#index")
      end

      it "routes to #new" do
        expect(get: "/platforms/new").to route_to("platforms#new")
      end

      it "routes to #show" do
        expect(get: "/platforms/1").to route_to("platforms#show", id: "1")
      end

      it "routes to #edit" do
        expect(get: "/platforms/1/edit").to route_to("platforms#edit", id: "1")
      end


      it "routes to #create" do
        expect(post: "/platforms").to route_to("platforms#create")
      end

      it "routes to #update via PUT" do
        expect(put: "/platforms/1").to route_to("platforms#update", id: "1")
      end

      it "routes to #update via PATCH" do
        expect(patch: "/platforms/1").to route_to("platforms#update", id: "1")
      end

      it "routes to #destroy" do
        expect(delete: "/platforms/1").to route_to("platforms#destroy", id: "1")
      end
    end
  end
end
