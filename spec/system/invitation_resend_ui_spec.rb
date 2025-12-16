# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Invitation Resend UI', :as_platform_manager, :js do
  include ActionView::RecordIdentifier
  include InvitationTestHelpers
  include BetterTogether::CapybaraFeatureHelpers

  let(:community) { create(:better_together_community, privacy: 'public') }
  let(:email) { 'test@example.com' }

  describe 'declined invitation resend button' do
    let!(:declined_invitation) do
      create(:better_together_community_invitation,
             invitable: community,
             invitee_email: email,
             status: 'declined')
    end

    it 'shows special resend button for declined invitations', :js do
      configure_host_platform
      capybara_login_as_platform_manager

      # Make platform manager a community organizer
      platform_manager = BetterTogether::User.find_by(email: 'manager@example.test')
      make_community_coordinator(platform_manager, community)

      visit better_together.community_path(locale: I18n.default_locale, id: community.slug)
      find('#members-tab').click

      # Find the declined invitation in the members list (it may have a specific ID)
      expect(page).to have_css("##{dom_id(declined_invitation)}", visible: true)

      # Should show the special "Resend to Declined" button
      within("##{dom_id(declined_invitation)}") do
        expect(page).to have_button(I18n.t('better_together.invitations.resend_declined', default: 'Resend to Declined'))
        expect(page).to have_css('.btn-outline-warning')
      end
    end

    it 'shows confirmation dialog when clicking resend to declined', :js do
      configure_host_platform
      capybara_login_as_platform_manager

      # Make platform manager a community organizer
      platform_manager = BetterTogether::User.find_by(email: 'manager@example.test')
      make_community_coordinator(platform_manager, community)

      visit better_together.community_path(locale: I18n.default_locale, id: community.slug)
      find('#members-tab').click

      # Wait for tab content to be visible
      expect(page).to have_css("##{dom_id(declined_invitation)}", visible: true)

      # Click the resend button
      within("##{dom_id(declined_invitation)}") do
        # Accept the confirm dialog
        accept_confirm(I18n.t('better_together.invitations.confirm_resend_declined',
                              default: 'This person previously declined this invitation. Are you sure you want to send it again?')) do
          click_button I18n.t('better_together.invitations.resend_declined', default: 'Resend to Declined')
        end
      end

      # Should see success message indicating invitation was queued
      expect(page).to have_text(/invitation.*queued.*sending/i)
    end
  end

  describe 'pending invitation resend button' do
    let!(:pending_invitation) do
      create(:better_together_community_invitation,
             invitable: community,
             invitee_email: 'pending@example.com',
             status: 'pending')
    end

    it 'shows normal resend button for pending invitations' do
      configure_host_platform
      capybara_login_as_platform_manager

      # Make platform manager a community organizer
      platform_manager = BetterTogether::User.find_by(email: 'manager@example.test')
      make_community_coordinator(platform_manager, community)

      visit better_together.community_path(locale: I18n.default_locale, id: community.slug)
      find('#members-tab').click

      # Wait for tab content to be visible
      expect(page).to have_css("##{dom_id(pending_invitation)}", visible: true)

      # Should show the normal "Resend" button
      within("##{dom_id(pending_invitation)}") do
        expect(page).to have_button(I18n.t('globals.resend', default: 'Resend'))
        expect(page).to have_css('.btn-outline-secondary')
        expect(page).not_to have_css('.btn-outline-warning')
      end
    end
  end
end
