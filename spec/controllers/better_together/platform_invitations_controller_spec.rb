# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformInvitationsController, :as_platform_manager do
  include Devise::Test::ControllerHelpers
  include Rails.application.routes.url_helpers
  include AutomaticTestConfiguration

  routes { BetterTogether::Engine.routes }
  let(:locale) { I18n.default_locale }
  let(:user) { find_or_create_test_user('platform_manager@example.test', 'password12345', :platform_manager) }
  let(:person) { user.person }
  let(:platform) { create(:better_together_platform, name: 'Test Platform') }
  let(:community) { create(:better_together_community, platform: platform) }

  before do
    # Set up platform manager relationship
    create(:better_together_person_platform_membership,
           member: person,
           joinable: platform,
           role: create(:better_together_role, :platform_manager))
  end

  describe 'GET #index' do
    let!(:invitation1) { create(:better_together_invitation, invitee_email: 'user1@example.com', platform: platform) }
    let!(:invitation2) { create(:better_together_invitation, invitee_email: 'user2@example.com', platform: platform) }

    context 'when user is authorized' do
      it 'returns http success' do
        get :index, params: { locale: locale, platform_id: platform.id }
        expect(response).to have_http_status(:success)
      end

      it 'assigns @platform' do
        get :index, params: { locale: locale, platform_id: platform.id }
        expect(assigns(:platform)).to eq(platform)
      end

      it 'assigns @platform_invitations with all platform invitations' do
        get :index, params: { locale: locale, platform_id: platform.id }
        expect(assigns(:platform_invitations)).to contain_exactly(invitation1, invitation2)
      end

      it 'includes proper associations for optimal loading' do
        get :index, params: { locale: locale, platform_id: platform.id }

        # Verify that associations are preloaded to prevent N+1 queries
        invitations = assigns(:platform_invitations)
        expect(invitations.first.association(:inviter)).to be_loaded
        expect(invitations.first.association(:invitee)).to be_loaded if invitations.first.invitee.present?
      end

      context 'with filtering' do
        let!(:pending_invitation) { create(:better_together_invitation, status: 'pending', platform: platform) }
        let!(:accepted_invitation) { create(:better_together_invitation, status: 'accepted', platform: platform) }

        it 'filters by status when provided' do
          get :index, params: { locale: locale, platform_id: platform.id, status: 'pending' }
          expect(assigns(:platform_invitations)).to include(pending_invitation)
          expect(assigns(:platform_invitations)).not_to include(accepted_invitation)
        end
      end

      context 'with search' do
        let!(:john_invitation) do
          create(:better_together_invitation, invitee_email: 'john@example.com', platform: platform)
        end
        let!(:jane_invitation) do
          create(:better_together_invitation, invitee_email: 'jane@example.com', platform: platform)
        end

        it 'searches by email when provided' do
          get :index, params: { locale: locale, platform_id: platform.id, search: 'john' }
          expect(assigns(:platform_invitations)).to include(john_invitation)
          expect(assigns(:platform_invitations)).not_to include(jane_invitation)
        end
      end
    end

    context 'when user is not authorized' do
      let(:regular_user) { create(:better_together_person) }

      before do
        sign_out user
        sign_in regular_user.user
      end

      it 'raises authorization error' do
        expect do
          get :index, params: { locale: locale, platform_id: platform.id }
        end.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'when not authenticated' do
      before { sign_out user }

      it 'redirects to sign in' do
        get :index, params: { locale: locale, platform_id: platform.id }
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/users/sign-in')
      end
    end

    context 'as turbo frame request' do
      it 'renders the turbo frame layout' do
        get :index, params: { locale: locale, platform_id: platform.id },
                    headers: { 'Turbo-Frame' => 'platform-invitations' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('turbo-frame')
      end
    end
  end

  describe 'POST #create' do
    let(:valid_attributes) do
      {
        invitee_email: 'newuser@example.com',
        message: 'Welcome to our platform!',
        community_role_id: create(:better_together_role, :community_member).id,
        platform_role_id: create(:better_together_role, :platform_member).id
      }
    end

    context 'with valid attributes' do
      it 'creates a new invitation' do
        expect do
          post :create, params: {
            locale: locale,
            platform_id: platform.id,
            invitation: valid_attributes
          }
        end.to change(BetterTogether::Invitation, :count).by(1)
      end

      it 'redirects to platform invitations index' do
        post :create, params: {
          locale: locale,
          platform_id: platform.id,
          invitation: valid_attributes
        }
        expect(response).to redirect_to(platform_platform_invitations_path(platform, locale: locale))
      end

      it 'sets success flash message' do
        post :create, params: {
          locale: locale,
          platform_id: platform.id,
          invitation: valid_attributes
        }
        expect(flash[:notice]).to be_present
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) { { invitee_email: '' } }

      it 'does not create an invitation' do
        expect do
          post :create, params: {
            locale: locale,
            platform_id: platform.id,
            invitation: invalid_attributes
          }
        end.not_to change(BetterTogether::Invitation, :count)
      end

      it 'renders the index template with errors' do
        post :create, params: {
          locale: locale,
          platform_id: platform.id,
          invitation: invalid_attributes
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(assigns(:invitation)).to be_present
        expect(assigns(:invitation).errors).not_to be_empty
      end
    end
  end

  describe 'PATCH #resend' do
    let!(:invitation) { create(:better_together_invitation, platform: platform, status: 'pending') }

    it 'updates the invitation sent_at timestamp' do
      expect do
        patch :resend, params: { locale: locale, platform_id: platform.id, id: invitation.id }
      end.to(change { invitation.reload.sent_at })
    end

    it 'redirects to platform invitations index' do
      patch :resend, params: { locale: locale, platform_id: platform.id, id: invitation.id }
      expect(response).to redirect_to(platform_platform_invitations_path(platform, locale: locale))
    end

    it 'sets success flash message' do
      patch :resend, params: { locale: locale, platform_id: platform.id, id: invitation.id }
      expect(flash[:notice]).to be_present
    end
  end

  describe 'DELETE #destroy' do
    let!(:invitation) { create(:better_together_invitation, platform: platform) }

    it 'deletes the invitation' do
      expect do
        delete :destroy, params: { locale: locale, platform_id: platform.id, id: invitation.id }
      end.to change(BetterTogether::Invitation, :count).by(-1)
    end

    it 'redirects to platform invitations index' do
      delete :destroy, params: { locale: locale, platform_id: platform.id, id: invitation.id }
      expect(response).to redirect_to(platform_platform_invitations_path(platform, locale: locale))
    end

    it 'sets success flash message' do
      delete :destroy, params: { locale: locale, platform_id: platform.id, id: invitation.id }
      expect(flash[:notice]).to be_present
    end
  end
end
