# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Community Invitation Review', :no_auth, :skip_host_setup do
  let!(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
  let!(:community) { create(:better_together_community) } # Create a regular community, not host
  let(:inviter) { create(:better_together_person) }
  let!(:invitation) { create(:better_together_community_invitation, invitable: community, inviter: inviter) }

  before do
    platform.update!(privacy: 'private')
    # Mark setup wizard as completed to prevent redirects
    wizard = BetterTogether::Wizard.find_or_create_by(identifier: 'host_setup')
    wizard.mark_completed
  end

  context 'when accessing community with valid invitation token' do
    it 'displays the invitation review section' do
      get "/en/c/#{community.slug}?invitation_token=#{invitation.token}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('invitation-review')
      expect_html_contents(
        I18n.t('better_together.invitations.review', default: 'Invitation'),
        I18n.t('better_together.invitations.accept', default: 'Accept'),
        I18n.t('better_together.invitations.decline', default: 'Decline')
      )
    end

    it 'displays the pending status badge' do
      get "/en/c/#{community.slug}?invitation_token=#{invitation.token}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('badge bg-warning text-dark')
      expect_html_content(I18n.t('better_together.invitations.status.pending', default: 'Pending'))
    end
  end

  context 'when accessing community without invitation token' do
    before do
      platform.update!(privacy: 'public')
    end

    it 'does not display the invitation review section' do
      get "/en/c/#{community.slug}"

      # Expect redirect (either to setup wizard or community page depending on platform state)
      expect(response).to have_http_status(:found)
    end
  end
end
