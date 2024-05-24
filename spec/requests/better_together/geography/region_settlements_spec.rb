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
  RSpec.describe "/geography/region_settlements", type: :request do
        include Engine.routes.url_helpers
  
    # This should return the minimal set of attributes required to create a valid
    #::BetterTogether::Geography::RegionSettlement. As you add validations to::BetterTogether::Geography::RegionSettlement, be sure to
    # adjust the attributes here as well.
    let(:valid_attributes) {
      skip("Add a hash of attributes valid for your model")
    }

    let(:invalid_attributes) {
      skip("Add a hash of attributes invalid for your model")
    }

    describe "GET /index" do
      it "renders a successful response" do
       ::BetterTogether::Geography::RegionSettlement.create! valid_attributes
        get geography_region_settlements_url
        # expect(response).to be_successful
      end
    end

    describe "GET /show" do
      it "renders a successful response" do
        region_settlement =::BetterTogether::Geography::RegionSettlement.create! valid_attributes
        get geography_region_settlement_url(region_settlement)
        # expect(response).to be_successful
      end
    end

    describe "GET /new" do
      it "renders a successful response" do
        get new_geography_region_settlement_url
        # expect(response).to be_successful
      end
    end

    describe "GET /edit" do
      it "renders a successful response" do
        region_settlement =::BetterTogether::Geography::RegionSettlement.create! valid_attributes
        get edit_geography_region_settlement_url(region_settlement)
        # expect(response).to be_successful
      end
    end

    describe "POST /create" do
      context "with valid parameters" do
        it "creates a new::BetterTogether::Geography::RegionSettlement" do
          expect {
            post geography_region_settlements_url, params: { geography_region_settlement: valid_attributes }
          }.to change(Geography::RegionSettlement, :count).by(1)
        end

        it "redirects to the created geography_region_settlement" do
          post geography_region_settlements_url, params: { geography_region_settlement: valid_attributes }
          # expect(response).to redirect_to(geography_region_settlement_url(Geography::RegionSettlement.last))
        end
      end

      context "with invalid parameters" do
        it "does not create a new::BetterTogether::Geography::RegionSettlement" do
          expect {
            post geography_region_settlements_url, params: { geography_region_settlement: invalid_attributes }
          }.to change(Geography::RegionSettlement, :count).by(0)
        end

    
        it "renders a response with 422 status (i.e. to display the 'new' template)" do
          post geography_region_settlements_url, params: { geography_region_settlement: invalid_attributes }
          # expect(response).to have_http_status(:unprocessable_entity)
        end
    
      end
    end

    describe "PATCH /update" do
      context "with valid parameters" do
        let(:new_attributes) {
          skip("Add a hash of attributes valid for your model")
        }

        it "updates the requested geography_region_settlement" do
          region_settlement =::BetterTogether::Geography::RegionSettlement.create! valid_attributes
          patch geography_region_settlement_url(region_settlement), params: { geography_region_settlement: new_attributes }
          region_settlement.reload
          skip("Add assertions for updated state")
        end

        it "redirects to the geography_region_settlement" do
          region_settlement =::BetterTogether::Geography::RegionSettlement.create! valid_attributes
          patch geography_region_settlement_url(region_settlement), params: { geography_region_settlement: new_attributes }
          region_settlement.reload
          # expect(response).to redirect_to(geography_region_settlement_url(region_settlement))
        end
      end

      context "with invalid parameters" do
    
        it "renders a response with 422 status (i.e. to display the 'edit' template)" do
          region_settlement =::BetterTogether::Geography::RegionSettlement.create! valid_attributes
          patch geography_region_settlement_url(region_settlement), params: { geography_region_settlement: invalid_attributes }
          # expect(response).to have_http_status(:unprocessable_entity)
        end
    
      end
    end

    describe "DELETE /destroy" do
      it "destroys the requested geography_region_settlement" do
        region_settlement =::BetterTogether::Geography::RegionSettlement.create! valid_attributes
        expect {
          delete geography_region_settlement_url(region_settlement)
        }.to change(Geography::RegionSettlement, :count).by(-1)
      end

      it "redirects to the geography_region_settlements list" do
        region_settlement =::BetterTogether::Geography::RegionSettlement.create! valid_attributes
        delete geography_region_settlement_url(region_settlement)
        # expect(response).to redirect_to(geography_region_settlements_url)
      end
    end
  end
end
