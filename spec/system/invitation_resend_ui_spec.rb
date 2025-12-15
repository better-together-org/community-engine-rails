# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Invitation Resend UI', type: :system, :as_platform_manager do
  let(:community) { create(:better_together_community) }
  let(:email) { 'test@example.com' }

  before do
    # Configure host platform and login automatically via metadata
  end

  describe 'declined invitation resend button' do
    let!(:declined_invitation) do 
      create(:better_together_invitation, 
             invitable: community, 
             invitee_email: email, 
             status: 'declined')
    end

    it 'shows special resend button for declined invitations', :js do
      visit better_together.community_path(community)

      # Should show the special "Resend to Declined" button
      within("##{dom_id(declined_invitation)}") do
        expect(page).to have_button(t('better_together.invitations.resend_declined', default: 'Resend to Declined'))
        expect(page).to have_css('.btn-outline-warning')
      end
    end

    it 'shows confirmation dialog when clicking resend to declined', :js do
      visit better_together.community_path(community)

      # Click the resend button
      within("##{dom_id(declined_invitation)}") do
        # Accept the confirm dialog
        accept_confirm(t('better_together.invitations.confirm_resend_declined', 
                        default: 'This person previously declined this invitation. Are you sure you want to send it again?')) do
          click_button t('better_together.invitations.resend_declined', default: 'Resend to Declined')
        end
      end

      # Should see success message
      expect(page).to have_text(/invitation.*sent/i)
    end
  end

  describe 'pending invitation resend button' do
    let!(:pending_invitation) do 
      create(:better_together_invitation, 
             invitable: community, 
             invitee_email: 'pending@example.com', 
             status: 'pending')
    end

    it 'shows normal resend button for pending invitations' do
      visit better_together.community_path(community)

      # Should show the normal "Resend" button
      within("##{dom_id(pending_invitation)}") do
        expect(page).to have_button(t('globals.resend', default: 'Resend'))
        expect(page).to have_css('.btn-outline-secondary')
        expect(page).not_to have_css('.btn-outline-warning')
      end
    end
  end
end