# frozen_string_literal: true

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
  RSpec.describe '/platforms', type: :request do # rubocop:todo Metrics/BlockLength
    include Engine.routes.url_helpers

    # This should return the minimal set of attributes required to create a valid
    # Platform. As you add validations to Platform, be sure to
    # adjust the attributes here as well.
    let(:valid_attributes) do
      skip('Add a hash of attributes valid for your model')
    end

    let(:invalid_attributes) do
      skip('Add a hash of attributes invalid for your model')
    end

    describe 'GET /index' do
      it 'renders a successful response' do
        Platform.create! valid_attributes
        get platforms_url
        expect(response).to be_successful
      end
    end

    describe 'GET /show' do
      it 'renders a successful response' do
        platform = Platform.create! valid_attributes
        get platform_url(platform)
        expect(response).to be_successful
      end
    end

    describe 'GET /new' do
      it 'renders a successful response' do
        # get new_platform_url
        # expect(response).to be_successful
      end
    end

    describe 'GET /edit' do
      it 'renders a successful response' do
        platform = Platform.create! valid_attributes
        get edit_platform_url(platform)
        expect(response).to be_successful
      end
    end

    describe 'POST /create' do
      context 'with valid parameters' do
        it 'creates a new Platform' do
          expect do
            post platforms_url, params: { platform: valid_attributes }
          end.to change(Platform, :count).by(1)
        end

        it 'redirects to the created platform' do
          post platforms_url, params: { platform: valid_attributes }
          expect(response).to redirect_to(platform_url(Platform.last))
        end
      end

      context 'with invalid parameters' do
        it 'does not create a new Platform' do
          expect do
            post platforms_url, params: { platform: invalid_attributes }
          end.to change(Platform, :count).by(0)
        end

        it "renders a response with 422 status (i.e. to display the 'new' template)" do
          post platforms_url, params: { platform: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    describe 'PATCH /update' do
      context 'with valid parameters' do
        let(:new_attributes) do
          skip('Add a hash of attributes valid for your model')
        end

        it 'updates the requested platform' do
          platform = Platform.create! valid_attributes
          patch platform_url(platform), params: { platform: new_attributes }
          platform.reload
          skip('Add assertions for updated state')
        end

        it 'redirects to the platform' do
          platform = Platform.create! valid_attributes
          patch platform_url(platform), params: { platform: new_attributes }
          platform.reload
          expect(response).to redirect_to(platform_url(platform))
        end
      end

      context 'with invalid parameters' do
        it "renders a response with 422 status (i.e. to display the 'edit' template)" do
          platform = Platform.create! valid_attributes
          patch platform_url(platform), params: { platform: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    describe 'DELETE /destroy' do
      it 'destroys the requested platform' do
        platform = Platform.create! valid_attributes
        expect do
          delete platform_url(platform)
        end.to change(Platform, :count).by(-1)
      end

      it 'redirects to the platforms list' do
        platform = Platform.create! valid_attributes
        delete platform_url(platform)
        expect(response).to redirect_to(platforms_url)
      end
    end
  end
end