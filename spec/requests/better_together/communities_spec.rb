require 'rails_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to test the controller code that
# was generated by Rails when you ran the scaffold generator.
#
# It assumes that the implementation code is generated by the rails scaffold
# generator. If you are using any extension libraries to generate different
# controller code, this generated spec may or may not pass.
#
# It only uses APIs available in rails and/or rspec-rails. There are a number
# of tools you can use to make these specs even more expressive, but we're
# sticking to rails and rspec-rails APIs to keep things simple and stable.

module BetterTogether
  RSpec.describe "/communities", type: :request do
        include Engine.routes.url_helpers
  
    # This should return the minimal set of attributes required to create a valid
    # Community. As you add validations to Community, be sure to
    # adjust the attributes here as well.
    let(:valid_attributes) {
      skip("Add a hash of attributes valid for your model")
    }

    let(:invalid_attributes) {
      skip("Add a hash of attributes invalid for your model")
    }

    describe "GET /index" do
      it "renders a successful response" do
        Community.create! valid_attributes
        get communities_url
        expect(response).to be_successful
      end
    end

    describe "GET /show" do
      it "renders a successful response" do
        community = Community.create! valid_attributes
        get community_url(community)
        expect(response).to be_successful
      end
    end

    describe "GET /new" do
      it "renders a successful response" do
        get new_community_url
        expect(response).to be_successful
      end
    end

    describe "GET /edit" do
      it "renders a successful response" do
        community = Community.create! valid_attributes
        get edit_community_url(community)
        expect(response).to be_successful
      end
    end

    describe "POST /create" do
      context "with valid parameters" do
        it "creates a new Community" do
          expect {
            post communities_url, params: { community: valid_attributes }
          }.to change(Community, :count).by(1)
        end

        it "redirects to the created community" do
          post communities_url, params: { community: valid_attributes }
          expect(response).to redirect_to(community_url(Community.last))
        end
      end

      context "with invalid parameters" do
        it "does not create a new Community" do
          expect {
            post communities_url, params: { community: invalid_attributes }
          }.to change(Community, :count).by(0)
        end

    
        it "renders a response with 422 status (i.e. to display the 'new' template)" do
          post communities_url, params: { community: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_entity)
        end
    
      end
    end

    describe "PATCH /update" do
      context "with valid parameters" do
        let(:new_attributes) {
          skip("Add a hash of attributes valid for your model")
        }

        it "updates the requested community" do
          community = Community.create! valid_attributes
          patch community_url(community), params: { community: new_attributes }
          community.reload
          skip("Add assertions for updated state")
        end

        it "redirects to the community" do
          community = Community.create! valid_attributes
          patch community_url(community), params: { community: new_attributes }
          community.reload
          expect(response).to redirect_to(community_url(community))
        end
      end

      context "with invalid parameters" do
    
        it "renders a response with 422 status (i.e. to display the 'edit' template)" do
          community = Community.create! valid_attributes
          patch community_url(community), params: { community: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_entity)
        end
    
      end
    end

    describe "DELETE /destroy" do
      it "destroys the requested community" do
        community = Community.create! valid_attributes
        expect {
          delete community_url(community)
        }.to change(Community, :count).by(-1)
      end

      it "redirects to the communities list" do
        community = Community.create! valid_attributes
        delete community_url(community)
        expect(response).to redirect_to(communities_url)
      end
    end
  end
end