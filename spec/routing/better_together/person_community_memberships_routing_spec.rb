require "rails_helper"

module BetterTogether
  RSpec.describe PersonCommunityMembershipsController, type: :routing do
    describe "routing" do
      it "routes to #index" do
        expect(get: "/bt/host/person_community_memberships").to route_to("better_together/person_community_memberships#index")
      end

      it "routes to #new" do
        expect(get: "/bt/host/person_community_memberships/new").to route_to("better_together/person_community_memberships#new")
      end

      it "routes to #show" do
        # expect(get: "/bt/host/person_community_memberships/1").to route_to("better_together/person_community_memberships#show", id: "1")
      end

      it "routes to #edit" do
        # expect(get: "/bt/host/person_community_memberships/1/edit").to route_to("better_together/person_community_memberships#edit", id: "1")
      end


      it "routes to #create" do
        expect(post: "/bt/host/person_community_memberships").to route_to("better_together/person_community_memberships#create")
      end

      it "routes to #update via PUT" do
        # expect(put: "/bt/host/person_community_memberships/1").to route_to("better_together/person_community_memberships#update", id: "1")
      end

      it "routes to #update via PATCH" do
        # expect(patch: "/bt/host/person_community_memberships/1").to route_to("better_together/person_community_memberships#update", id: "1")
      end

      it "routes to #destroy" do
        # expect(delete: "/bt/host/person_community_memberships/1").to route_to("better_together/person_community_memberships#destroy", id: "1")
      end
    end
  end
end
