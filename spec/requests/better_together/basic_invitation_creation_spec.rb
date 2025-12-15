# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Basic Invitation Creation', type: :request do
  let(:community) { create(:better_together_community) }
  let(:email) { 'test@example.com' }

  before do
    configure_host_platform
    login('user@example.com', 'password')
  end

  describe 'creating invitations' do
    it 'successfully creates an invitation for a new email' do
      expect do
        post better_together.community_invitations_path(community),
             params: { invitation: { invitee_email: email }, locale: I18n.default_locale }
      end.to change(BetterTogether::Invitation, :count).by(1)

      expect(response).to redirect_to(community)
      expect(flash[:notice]).to be_present
    end
  end
end
