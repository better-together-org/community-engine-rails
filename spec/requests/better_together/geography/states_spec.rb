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
  RSpec.describe "/geography/states", type: :request do
        include Engine.routes.url_helpers
  
    # This should return the minimal set of attributes required to create a valid
    #::BetterTogether::Geography::State. As you add validations to::BetterTogether::Geography::State, be sure to
    # adjust the attributes here as well.
    let(:valid_attributes) {
      skip("Add a hash of attributes valid for your model")
    }

    let(:invalid_attributes) {
      skip("Add a hash of attributes invalid for your model")
    }

    describe "GET /index" do
      it "renders a successful response" do
       ::BetterTogether::Geography::State.create! valid_attributes
        get geography_states_url
        # expect(response).to be_successful
      end
    end

    describe "GET /show" do
      it "renders a successful response" do
        state =::BetterTogether::Geography::State.create! valid_attributes
        get geography_state_url(state)
        # expect(response).to be_successful
      end
    end

    describe "GET /new" do
      it "renders a successful response" do
        get new_geography_state_url
        # expect(response).to be_successful
      end
    end

    describe "GET /edit" do
      it "renders a successful response" do
        state =::BetterTogether::Geography::State.create! valid_attributes
        get edit_geography_state_url(state)
        # expect(response).to be_successful
      end
    end

    describe "POST /create" do
      context "with valid parameters" do
        it "creates a new::BetterTogether::Geography::State" do
          expect {
            post geography_states_url, params: { geography_state: valid_attributes }
          }.to change(Geography::State, :count).by(1)
        end

        it "redirects to the created geography_state" do
          post geography_states_url, params: { geography_state: valid_attributes }
          # expect(response).to redirect_to(geography_state_url(Geography::State.last))
        end
      end

      context "with invalid parameters" do
        it "does not create a new::BetterTogether::Geography::State" do
          expect {
            post geography_states_url, params: { geography_state: invalid_attributes }
          }.to change(Geography::State, :count).by(0)
        end

    
        it "renders a response with 422 status (i.e. to display the 'new' template)" do
          post geography_states_url, params: { geography_state: invalid_attributes }
          # expect(response).to have_http_status(:unprocessable_entity)
        end
    
      end
    end

    describe "PATCH /update" do
      context "with valid parameters" do
        let(:new_attributes) {
          skip("Add a hash of attributes valid for your model")
        }

        it "updates the requested geography_state" do
          state =::BetterTogether::Geography::State.create! valid_attributes
          patch geography_state_url(state), params: { geography_state: new_attributes }
          state.reload
          skip("Add assertions for updated state")
        end

        it "redirects to the geography_state" do
          state =::BetterTogether::Geography::State.create! valid_attributes
          patch geography_state_url(state), params: { geography_state: new_attributes }
          state.reload
          # expect(response).to redirect_to(geography_state_url(state))
        end
      end

      context "with invalid parameters" do
    
        it "renders a response with 422 status (i.e. to display the 'edit' template)" do
          state =::BetterTogether::Geography::State.create! valid_attributes
          patch geography_state_url(state), params: { geography_state: invalid_attributes }
          # expect(response).to have_http_status(:unprocessable_entity)
        end
    
      end
    end

    describe "DELETE /destroy" do
      it "destroys the requested geography_state" do
        state =::BetterTogether::Geography::State.create! valid_attributes
        expect {
          delete geography_state_url(state)
        }.to change(Geography::State, :count).by(-1)
      end

      it "redirects to the geography_states list" do
        state =::BetterTogether::Geography::State.create! valid_attributes
        delete geography_state_url(state)
        # expect(response).to redirect_to(geography_states_url)
      end
    end
  end
end
