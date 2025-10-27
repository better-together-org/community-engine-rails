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
  let(:platform_slug) { platform.slug }
  let(:community) { create(:better_together_community, platform: platform) }

  before do
    configure_host_platform
    sign_in user
  end

  describe 'GET #index' do
    let!(:invitation1) do
      create(:better_together_platform_invitation, invitee_email: 'user1@example.com', invitable: platform)
    end
    let!(:invitation2) do
      create(:better_together_platform_invitation, invitee_email: 'user2@example.com', invitable: platform)
    end

    context 'when user is authorized' do
      it 'returns http success' do
        get :index, params: { locale: locale, platform_id: platform_slug }
        expect(response).to have_http_status(:success)
      end

      it 'assigns @platform' do
        get :index, params: { locale: locale, platform_id: platform_slug }
        expect(assigns(:platform)).to eq(platform)
      end

      it 'assigns @platform_invitations with all platform invitations' do
        get :index, params: { locale: locale, platform_id: platform_slug }
        expect(assigns(:platform_invitations)).to contain_exactly(invitation1, invitation2)
      end

      it 'includes proper associations for optimal loading' do
        get :index, params: { locale: locale, platform_id: platform_slug }

        # Verify that associations are preloaded to prevent N+1 queries
        invitations = assigns(:platform_invitations)
        expect(invitations.first.association(:inviter)).to be_loaded
        expect(invitations.first.association(:invitee)).to be_loaded if invitations.first.invitee.present?
      end

      context 'with filtering' do
        let!(:pending_invitation) do
          create(:better_together_platform_invitation, status: 'pending', invitable: platform)
        end
        let!(:accepted_invitation) do
          create(:better_together_platform_invitation, status: 'accepted', invitable: platform)
        end

        it 'filters by status when provided' do
          get :index, params: { locale: locale, platform_id: platform_slug, status: 'pending' }
          expect(assigns(:platform_invitations)).to include(pending_invitation)
          expect(assigns(:platform_invitations)).not_to include(accepted_invitation)
        end
      end

      context 'with search' do
        let!(:john_invitation) do
          create(:better_together_platform_invitation, invitee_email: 'john@example.com', invitable: platform)
        end
        let!(:jane_invitation) do
          create(:better_together_platform_invitation, invitee_email: 'jane@example.com', invitable: platform)
        end

        it 'searches by email when provided' do
          get :index, params: { locale: locale, platform_id: platform_slug, search: 'john' }
          expect(assigns(:platform_invitations)).to include(john_invitation)
          expect(assigns(:platform_invitations)).not_to include(jane_invitation)
        end
      end

      context 'with pagination' do
        before do
          # Create more invitations than the per-page limit (25)
          30.times do |i|
            create(:better_together_platform_invitation,
                   invitee_email: "user#{i}@example#{i}.com",
                   invitable: platform,
                   inviter: user.person)
          end
        end

        it 'paginates results' do
          get :index, params: { locale: locale, platform_id: platform_slug }
          expect(assigns(:platform_invitations).count).to eq(25)
          expect(assigns(:platform_invitations).current_page).to eq(1)
        end

        it 'supports page parameter' do
          get :index, params: { locale: locale, platform_id: platform_slug, page: 2 }
          expect(assigns(:platform_invitations).current_page).to eq(2)
        end
      end

      context 'with sorting' do
        let!(:old_invitation) do
          create(:better_together_platform_invitation, invitee_email: 'old@example.com', invitable: platform,
                                                       created_at: 2.days.ago)
        end
        let!(:new_invitation) do
          create(:better_together_platform_invitation, invitee_email: 'new@example.com', invitable: platform,
                                                       created_at: 1.day.ago)
        end

        it 'sorts by created_at when specified' do
          get :index,
              params: { locale: locale, platform_id: platform_slug, sort_by: 'created_at', sort_direction: 'asc' }
          invitations = assigns(:platform_invitations)
          expect(invitations.first).to eq(old_invitation)
        end

        it 'sorts by email when specified' do
          get :index,
              params: { locale: locale, platform_id: platform_slug, sort_by: 'invitee_email', sort_direction: 'asc' }
          invitations = assigns(:platform_invitations)
          expect(invitations.first.invitee_email).to eq('new@example.com')
        end
      end
    end

    context 'when not authenticated' do
      before { sign_out user }

      it 'redirects to sign in' do
        get :index, params: { locale: locale, platform_id: platform_slug }
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/users/sign-in')
      end
    end
  end

  describe 'POST #create' do
    let(:valid_attributes) do
      {
        invitee_email: 'newuser@example.com',
        message: 'Welcome to our platform!',
        community_role_id: create(:better_together_role, :community_role).id,
        platform_role_id: create(:better_together_role, :platform_role).id,
        type: 'BetterTogether::PlatformInvitation'
      }
    end

    context 'with valid attributes' do
      it 'creates a new invitation' do
        expect do
          post :create, params: {
            locale: locale,
            platform_id: platform_slug,
            platform_invitation: valid_attributes
          }
        end.to change(BetterTogether::PlatformInvitation, :count).by(1)
      end

      it 'redirects to platform show page' do
        post :create, params: {
          locale: locale,
          platform_id: platform_slug,
          platform_invitation: valid_attributes
        }
        expect(response.location).to include(platform_path(platform))
      end

      it 'sets success flash message' do
        post :create, params: {
          locale: locale,
          platform_id: platform_slug,
          platform_invitation: valid_attributes
        }
        expect(flash[:notice]).to be_present
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) do
        {
          invitee_email: '',
          community_role_id: create(:better_together_role, :community_role).id,
          platform_role_id: create(:better_together_role, :platform_role).id,
          type: 'BetterTogether::PlatformInvitation'
        }
      end

      it 'does not create an invitation' do
        expect do
          post :create, params: {
            locale: locale,
            platform_id: platform_slug,
            platform_invitation: invalid_attributes
          }
        end.not_to change(BetterTogether::PlatformInvitation, :count)
      end

      it 'renders the index template with errors' do
        post :create, params: {
          locale: locale,
          platform_id: platform_slug,
          platform_invitation: invalid_attributes
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(assigns(:platform_invitation)).to be_present
        expect(assigns(:platform_invitation).errors).not_to be_empty
      end
    end
  end

  describe 'PATCH #resend' do
    let!(:invitation) { create(:better_together_platform_invitation, invitable: platform, status: 'pending') }

    it 'queues the mailer job' do
      expect(BetterTogether::PlatformInvitationMailerJob).to receive(:perform_later).with(invitation.id)
      patch :resend, params: { locale: locale, platform_id: platform_slug, id: invitation.id }
    end

    it 'redirects to platform invitations index' do
      patch :resend, params: { locale: locale, platform_id: platform_slug, id: invitation.id }
      expect(response).to redirect_to(platform_platform_invitations_path(platform, locale: locale))
    end

    it 'sets success flash message' do
      patch :resend, params: { locale: locale, platform_id: platform_slug, id: invitation.id }
      expect(flash[:notice]).to be_present
    end
  end

  describe 'DELETE #destroy' do
    let!(:invitation) { create(:better_together_platform_invitation, invitable: platform) }

    it 'deletes the invitation' do
      expect do
        delete :destroy, params: { locale: locale, platform_id: platform_slug, id: invitation.id }
      end.to change(BetterTogether::PlatformInvitation, :count).by(-1)
    end

    it 'redirects to platform invitations index' do
      delete :destroy, params: { locale: locale, platform_id: platform_slug, id: invitation.id }
      expect(response).to redirect_to(platform_platform_invitations_path(platform, locale: locale))
    end

    it 'sets success flash message' do
      delete :destroy, params: { locale: locale, platform_id: platform_slug, id: invitation.id }
      expect(flash[:notice]).to be_present
    end
  end
end
