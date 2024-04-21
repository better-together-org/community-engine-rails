require "rails_helper"

module BetterTogether
  RSpec.describe BetterTogether::ResourcePermissionsController, type: :routing do
    describe "routing" do
      it "routes to #index" do
        expect(get: "/resource_permissions").to route_to("resource_permissions#index")
      end

      it "routes to #new" do
        expect(get: "/resource_permissions/new").to route_to("resource_permissions#new")
      end

      it "routes to #show" do
        expect(get: "/resource_permissions/1").to route_to("resource_permissions#show", id: "1")
      end

      it "routes to #edit" do
        expect(get: "/resource_permissions/1/edit").to route_to("resource_permissions#edit", id: "1")
      end


      it "routes to #create" do
        expect(post: "/resource_permissions").to route_to("resource_permissions#create")
      end

      it "routes to #update via PUT" do
        expect(put: "/resource_permissions/1").to route_to("resource_permissions#update", id: "1")
      end

      it "routes to #update via PATCH" do
        expect(patch: "/resource_permissions/1").to route_to("resource_permissions#update", id: "1")
      end

      it "routes to #destroy" do
        expect(delete: "/resource_permissions/1").to route_to("resource_permissions#destroy", id: "1")
      end
    end
  end
end
