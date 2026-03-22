# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Invitation Resend' do
  let(:community) { create(:better_together_community) }
  let(:invitation) { create(:better_together_community_invitation, invitable: community, status: 'declined') }

  before do
    configure_host_platform
    login('manager@example.test', 'SecureTest123!@#')
  end

  describe 'PUT /communities/:community_id/invitations/:id/resend' do
    context 'when invitation is declined' do
      it 'allows resending the invitation' do
        put better_together.resend_community_invitation_path(community, invitation, locale: I18n.default_locale),
            params: { force_resend: 'true' }

        expect(response).to have_http_status(:see_other) # POST-redirect-GET pattern
      end
    end

    context 'when invitation is pending' do
      let(:invitation) { create(:better_together_community_invitation, invitable: community, status: 'pending') }

      it 'allows resending the invitation' do
        put better_together.resend_community_invitation_path(community, invitation, locale: I18n.default_locale)

        expect(response).to have_http_status(:see_other) # POST-redirect-GET pattern
      end
    end

    context 'when invitation is accepted' do
      let(:invitation) { create(:better_together_community_invitation, invitable: community, status: 'accepted') }

      it 'does not allow resending the invitation' do
        put better_together.resend_community_invitation_path(community, invitation, locale: I18n.default_locale)

        # Should redirect with error message since policy blocks accepted invitation resend
        expect(response).to have_http_status(:found)
        expect(flash[:error]).to be_present
      end
    end
  end
end
