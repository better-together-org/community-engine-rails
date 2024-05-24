require "rails_helper"

module BetterTogether
  RSpec.describe ::BetterTogether::Geography::CountriesController, type: :routing do
    describe "routing" do
      it "routes to #index" do
        # expect(get: "/geography/countries").to route_to("geography/countries#index")
      end

      it "routes to #new" do
        # expect(get: "/geography/countries/new").to route_to("geography/countries#new")
      end

      it "routes to #show" do
        # expect(get: "/geography/countries/1").to route_to("geography/countries#show", id: "1")
      end

      it "routes to #edit" do
        # expect(get: "/geography/countries/1/edit").to route_to("geography/countries#edit", id: "1")
      end


      it "routes to #create" do
        # expect(post: "/geography/countries").to route_to("geography/countries#create")
      end

      it "routes to #update via PUT" do
        # expect(put: "/geography/countries/1").to route_to("geography/countries#update", id: "1")
      end

      it "routes to #update via PATCH" do
        # expect(patch: "/geography/countries/1").to route_to("geography/countries#update", id: "1")
      end

      it "routes to #destroy" do
        # expect(delete: "/geography/countries/1").to route_to("geography/countries#destroy", id: "1")
      end
    end
  end
end
