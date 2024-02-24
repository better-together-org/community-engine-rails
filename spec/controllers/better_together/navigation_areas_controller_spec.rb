# spec/controllers/better_together/navigation_areas_controller_spec.rb

require 'rails_helper'

RSpec.describe BetterTogether::NavigationAreasController, type: :controller do
  include_context 'engine routes for BetterTogether'

  let(:user) { create(:user) }
  let(:navigation_area) { create(:navigation_area) }
  let(:new_attributes) { attributes_for(:navigation_area) }
  let(:invalid_attributes) { attributes_for(:navigation_area).merge(name: nil) }

  before do
    # Assuming Devise or similar authentication mechanism
    sign_in user
  end

  describe "GET #index" do
    it "renders the index template for authorized users" do
      get :index
      expect(response).to render_template(:index)
      expect(assigns(:navigation_areas)).to eq(policy_scope(::BetterTogether::NavigationArea))
    end

    # Additional context for unauthorized users
  end

  describe "GET #show" do
    it "renders the show template for authorized users" do
      get :show, params: { id: navigation_area.id }
      expect(response).to render_template(:show)
    end

    # Additional context for unauthorized users
  end

  describe "GET #new" do
    it "renders the new template for authorized users" do
      get :new
      expect(response).to render_template(:new)
      expect(assigns(:navigation_area)).to be_a_new(::BetterTogether::NavigationArea)
    end

    # Additional context for unauthorized users
  end

  describe "GET #edit" do
    it "renders the edit template for authorized users" do
      get :edit, params: { id: navigation_area.id }
      expect(response).to render_template(:edit)
    end

    # Additional context for unauthorized users
  end

  describe "POST #create" do
    context "with valid attributes" do
      it "creates a new navigation area and redirects for authorized users" do
        expect {
          post :create, params: { navigation_area: attributes_for(:navigation_area) }
        }.to change(::BetterTogether::NavigationArea, :count).by(1)

        expect(response).to redirect_to(::BetterTogether::NavigationArea.last)
      end
    end

    context "with invalid attributes" do
      it "does not create a new navigation area and re-renders the new template" do
        expect {
          post :create, params: { navigation_area: invalid_attributes }
        }.to_not change(::BetterTogether::NavigationArea, :count)

        expect(response).to render_template(:new)
      end
    end
  end

  describe "PUT #update" do
    context "with valid attributes" do
      it "updates the navigation area and redirects for authorized users" do
        put :update, params: { id: navigation_area.id, navigation_area: new_attributes }
        navigation_area.reload

        expect(navigation_area.some_attribute).to eq(new_value)
        expect(response).to redirect_to(navigation_area)
      end
    end

    context "with invalid attributes" do
      it "does not update the navigation area and re-renders the edit template" do
        put :update, params: { id: navigation_area.id, navigation_area: invalid_attributes }
        expect(response).to render_template(:edit)
      end
    end
  end

  describe "DELETE #destroy" do
    it "destroys the navigation area and redirects for authorized users" do
      navigation_area = create(:navigation_area)
      expect {
        delete :destroy, params: { id: navigation_area.id }
      }.to change(::BetterTogether::NavigationArea, :count).by(-1)

      expect(response).to redirect_to(navigation_areas_url)
    end
  end
end
