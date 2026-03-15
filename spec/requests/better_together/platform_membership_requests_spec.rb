# frozen_string_literal: true

require 'rails_helper'

# @tagged env_required
RSpec.describe 'BetterTogether::PlatformMembershipRequests (approve/decline)', type: :request do
  let!(:platform) { BetterTogether::Platform.first || create(:better_together_platform) }
  let!(:community) { create(:better_together_community) }
  let!(:manager_user) { BetterTogether::User.find_by(email: 'manager@example.test') }

  let(:open_request) do
    create(:better_together_joatu_membership_request,
           target: community,
           status: 'open')
  end

  let(:manager_headers) { platform_manager_auth_headers(manager_user) }

  def approve_path(req)
    "/#{I18n.locale}/platforms/#{platform.slug}/membership_requests/#{req.id}/approve"
  end

  def decline_path(req)
    "/#{I18n.locale}/platforms/#{platform.slug}/membership_requests/#{req.id}/decline"
  end

  describe 'POST /platforms/:platform_id/membership_requests/:id/approve' do
    context 'as a platform manager' do
      before { sign_in manager_user }

      it 'changes status to fulfilled' do
        post approve_path(open_request), headers: { 'Accept' => 'text/html' }
        expect(open_request.reload.status).to eq('fulfilled')
      end

      it 'redirects to the index' do
        post approve_path(open_request), headers: { 'Accept' => 'text/html' }
        expect(response).to redirect_to(
          "/#{I18n.locale}/platforms/#{platform.slug}/membership_requests"
        )
      end

      context 'for an unauthenticated request (no creator)' do
        it 'creates a CommunityInvitation' do
          expect {
            post approve_path(open_request), headers: { 'Accept' => 'text/html' }
          }.to change(BetterTogether::CommunityInvitation, :count).by(1)
        end
      end
    end
  end

  describe 'POST /platforms/:platform_id/membership_requests/:id/decline' do
    context 'as a platform manager' do
      before { sign_in manager_user }

      it 'changes status to closed' do
        post decline_path(open_request), headers: { 'Accept' => 'text/html' }
        expect(open_request.reload.status).to eq('closed')
      end

      it 'redirects to the index' do
        post decline_path(open_request), headers: { 'Accept' => 'text/html' }
        expect(response).to redirect_to(
          "/#{I18n.locale}/platforms/#{platform.slug}/membership_requests"
        )
      end

      it 'does not create a CommunityInvitation' do
        expect {
          post decline_path(open_request), headers: { 'Accept' => 'text/html' }
        }.not_to change(BetterTogether::CommunityInvitation, :count)
      end
    end
  end
end
