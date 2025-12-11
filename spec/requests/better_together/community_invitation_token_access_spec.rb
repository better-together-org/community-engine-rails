# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Community Invitation Token Access' do
  let!(:platform) { BetterTogether::Platform.find_by(host: true) }
  let!(:community) { create(:better_together_community) }
  let(:inviter) { create(:better_together_person) }
  let!(:invitation) { create(:better_together_community_invitation, invitable: community, inviter: inviter) }

  before do
    platform&.update!(privacy: 'private')
  end

  context 'when accessing private platform community via invitation token' do
    it 'allows access to community with valid invitation token' do
      get "/en/communities/#{community.slug}?invitation_token=#{invitation.token}"
      expect(response).to have_http_status(:ok)

      # Check that the invitation review section is present
      expect(response.body).to include('invitation-review')
      expect(response.body).to include('Invitation')  # Should contain the review heading
      expect(response.body).to include('Accept')      # Accept button (English)
      expect(response.body).to include('Decline')     # Decline button (English)
    end

    it 'stores invitation token in session for platform privacy bypass' do
      get "/en/communities/#{community.slug}?invitation_token=#{invitation.token}"
      expect(session[:community_invitation_token]).to eq(invitation.token)
    end

    it 'denies access without invitation token on private platform' do
      get "/en/communities/#{community.slug}"
      expect(response).to redirect_to(new_user_session_path(locale: 'en'))
    end
  end

  context 'when invitation token is invalid' do
    it 'denies access with expired invitation token' do
      invitation.update!(valid_until: 1.day.ago)
      get "/en/communities/#{community.slug}?invitation_token=#{invitation.token}"
      expect(response).to redirect_to(new_user_session_path(locale: 'en'))
    end

    it 'denies access with non-existent invitation token' do
      get "/en/communities/#{community.slug}?invitation_token=invalid_token"
      expect(response).to have_http_status(:not_found)
    end
  end
end
