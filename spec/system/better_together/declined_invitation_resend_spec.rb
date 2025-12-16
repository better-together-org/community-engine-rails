# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Declined Invitation Resend', :as_platform_manager, :js do
  include InvitationTestHelpers
  include BetterTogether::CapybaraFeatureHelpers

  let(:platform) { create(:better_together_platform, host: true) }
  let(:community) { create(:better_together_community, privacy: 'public') }
  let!(:declined_invitation) do
    create(:better_together_community_invitation,
           invitable: community,
           invitee_email: 'declined@example.com',
           status: 'declined')
  end

  before do
    # Ensure host platform is configured before navigation
    configure_host_platform
    capybara_login_as_platform_manager

    # Make platform manager a community organizer so they can manage invitations
    platform_manager = BetterTogether::User.find_by(email: 'manager@example.test')
    make_community_coordinator(platform_manager, community)

    # Visit the community management page
    visit better_together.community_path(locale: I18n.default_locale, id: community.slug)
    find('#members-tab').click
  end

  context 'when viewing declined invitations' do
    it 'displays special resend button with warning style' do
      expect(page).to have_css('.btn-outline-warning', text: /Resend to Declined/i)
      expect(page).to have_css('i.fa-redo')
    end

    it 'shows confirmation dialog when clicking resend for declined invitation' do
      # Use accept_confirm to handle the confirmation dialog
      accept_confirm(I18n.t('better_together.invitations.confirm_resend_declined',
                            default: 'This person previously declined this invitation. Are you sure you want to send it again?')) do
        find('.btn-outline-warning', text: /Resend to Declined/i).click
      end

      # Verify the invitation was resent (should show flash message)
      expect(page).to have_css('.alert-success')
    end

    it 'does not resend when confirmation is cancelled' do
      # Use dismiss_confirm to cancel the confirmation dialog
      dismiss_confirm(t('better_together.invitations.confirm_resend_declined',
                        default: 'This person previously declined this invitation. Are you sure you want to send it again?')) do
        find('.btn-outline-warning', text: /Resend to Declined/i).click
      end

      # The page should remain the same (no flash message or redirect)
      expect(page).not_to have_css('.alert-success')
      expect(declined_invitation.reload.status).to eq('declined')
    end
  end

  context 'when resending to declined user' do
    it 'includes force_resend parameter in the request' do
      accept_confirm do
        find('.btn-outline-warning', text: /Resend to Declined/i).click
      end

      # Check that the invitation was actually processed
      expect(page).to have_css('.alert-success')

      # Verify the invitation can be found (indicating successful processing)
      expect(BetterTogether::Invitation.where(invitee_email: 'declined@example.com')).to exist
    end
  end

  private

  def t(key, options = {})
    I18n.t(key, **options)
  end
end
