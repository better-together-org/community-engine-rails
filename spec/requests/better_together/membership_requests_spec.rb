# frozen_string_literal: true

require 'rails_helper'

# @tagged hermetic
RSpec.describe 'BetterTogether::MembershipRequests' do
  let!(:community) { create(:better_together_community, :membership_requests_enabled) }
  let!(:host_platform) do
    BetterTogether::Platform.find_by(host: true)&.tap do |platform|
      platform.update!(privacy: 'public', allow_membership_requests: true)
    end || create(:better_together_platform, :host, :public, :membership_requests_enabled)
  end
  let!(:community_platform) { create(:better_together_platform, :membership_requests_enabled, community: community) }
  let(:base_path)  { "/#{I18n.locale}/c/#{community.slug}/membership_requests" }
  let(:new_path)   { "#{base_path}/new" }

  let(:valid_params) do
    {
      joatu_membership_request: {
        requestor_name: 'Alice Example',
        requestor_email: 'alice@example.test',
        referral_source: 'A friend',
        description: 'I want to help the community.'
      }
    }.merge(bot_defense_payload(:membership_request))
  end

  def bot_defense_payload(form_id)
    challenge = travel_to(3.seconds.ago) do
      BetterTogether::BotDefense::Challenge.issue(form_id:)
    end

    {
      bot_defense: {
        token: challenge.token,
        trap_values: { challenge.trap_field => '' }
      }
    }
  end

  # ---------------------------------------------------------------------------
  # Public submission (no auth)
  # ---------------------------------------------------------------------------
  before { logout }

  describe 'GET /c/:community_id/membership_requests/new' do
    it 'renders without authentication' do
      get new_path
      expect(response).to have_http_status(:ok)
    end

    it 'renders the membership_request form' do
      get new_path
      expect(response.body).to include('membership_request')
    end
  end

  describe 'disabled membership request intake' do
    let!(:community) { create(:better_together_community, allow_membership_requests: false) }

    it 'does not render the public request form' do
      get new_path

      expect(response).to have_http_status(:forbidden)
    end

    it 'does not create a membership request' do
      expect do
        post base_path, params: valid_params
      end.not_to change(BetterTogether::Joatu::MembershipRequest, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /c/:community_id/membership_requests' do
    context 'with valid params (unauthenticated)' do
      it 'creates the membership request' do
        expect do
          post base_path, params: valid_params
        end.to change(BetterTogether::Joatu::MembershipRequest, :count).by(1)
      end

      it 'renders the success page' do
        post base_path, params: valid_params
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(
          I18n.t('better_together.membership_requests.success.heading', default: 'Request Received')
        )
      end

      it 'sets creator to nil (unauthenticated)' do
        post base_path, params: valid_params
        expect(BetterTogether::Joatu::MembershipRequest.last.creator).to be_nil
      end

      it 'sets the target community' do
        post base_path, params: valid_params
        expect(BetterTogether::Joatu::MembershipRequest.last.target).to eq(community)
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        { joatu_membership_request: { requestor_name: '', requestor_email: 'bad', description: '' } }
      end

      it 're-renders the form with 422' do
        post base_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not create a record' do
        expect do
          post base_path, params: invalid_params
        end.not_to change(BetterTogether::Joatu::MembershipRequest, :count)
      end
    end

    context 'with captcha hook' do
      it 'renders 422 when captcha fails' do
        BetterTogether::MembershipRequestsController.captcha_validation_proc = -> { false }
        post base_path, params: valid_params
        expect(response).to have_http_status(:unprocessable_content)
      ensure
        BetterTogether::MembershipRequestsController.captcha_validation_proc = nil
      end
    end

    context 'without bot defense proof' do
      it 'rejects the submission' do
        unsafe_params = valid_params.except(:bot_defense)

        expect do
          post base_path, params: unsafe_params
        end.not_to change(BetterTogether::Joatu::MembershipRequest, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Community-manager actions (require authentication)
  # ---------------------------------------------------------------------------
  describe 'community manager actions' do
    let!(:manager_person) { create(:better_together_person) }
    let!(:open_mr) do
      create(:better_together_joatu_membership_request,
             target: community,
             status: 'open')
    end
    let!(:manager_user) do
      create(:better_together_user, :confirmed, person: manager_person, password: 'SecureTest123!@#')
    end
    let!(:community_manager_role) do
      BetterTogether::Role.find_by(identifier: 'community_manager',
                                   resource_type: 'BetterTogether::Community') ||
        create(:better_together_role, identifier: 'community_manager',
                                      name: 'Community Manager', resource_type: 'BetterTogether::Community')
    end
    let!(:membership) do
      create(:better_together_person_community_membership,
             joinable: community,
             member: manager_person,
             role: community_manager_role)
    end

    before { sign_in manager_user }

    describe 'GET /c/:community_id/membership_requests' do
      it 'lists open requests' do
        get base_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'GET /c/:community_id/membership_requests/:id' do
      it 'shows the request' do
        get "#{base_path}/#{open_mr.id}"
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'POST /c/:community_id/membership_requests/:id/approve' do
      it 'changes status to fulfilled' do
        post "#{base_path}/#{open_mr.id}/approve"
        expect(open_mr.reload.status).to eq('fulfilled')
      end

      it 'redirects to the index' do
        post "#{base_path}/#{open_mr.id}/approve"
        expect(response).to redirect_to(base_path)
      end
    end

    describe 'POST /c/:community_id/membership_requests/:id/decline' do
      it 'changes status to closed' do
        post "#{base_path}/#{open_mr.id}/decline"
        expect(open_mr.reload.status).to eq('closed')
      end

      it 'redirects to the index' do
        post "#{base_path}/#{open_mr.id}/decline"
        expect(response).to redirect_to(base_path)
      end
    end

    describe 'DELETE /c/:community_id/membership_requests/:id' do
      it 'destroys the request and redirects' do
        expect do
          delete "#{base_path}/#{open_mr.id}"
        end.to change(BetterTogether::Joatu::MembershipRequest, :count).by(-1)
        expect(response).to redirect_to(base_path)
      end
    end
  end
end
