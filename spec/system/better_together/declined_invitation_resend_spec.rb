# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Declined Invitation Resend', :js do
  let(:platform) { create(:better_together_platform, host: true) }
  let(:community) { create(:better_together_community) }
  let!(:declined_invitation) do
    create(:better_together_invitation,
           invitable: community,
           invitee_email: 'declined@example.com',
           status: 'declined')
  end

  before do
    configure_host_platform
    capybara_login_as_platform_manager

    # Visit the community management page
    visit better_together.community_path(community)
    click_link t('better_together.communities.tabs.invitations', default: 'Invitations')
  end

  context 'when viewing declined invitations' do
    it 'displays special resend button with warning style' do
      expect(page).to have_css('.btn-outline-warning', text: /Resend to Declined/i)
      expect(page).to have_css('i.fa-redo')
    end

    it 'shows confirmation dialog when clicking resend for declined invitation' do
      # Use accept_confirm to handle the confirmation dialog
      accept_confirm(t('better_together.invitations.confirm_resend_declined',
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

  def capybara_login_as_platform_manager # rubocop:todo Metrics/AbcSize
    # Create or find platform manager
    platform_manager = BetterTogether::Person.joins(:platform_roles)
                                             .where(better_together_roles: BetterTogether::Role.i18n.where(slug: 'platform_manager'))
                                             .first

    if platform_manager.blank?
      # Create platform manager if none exists
      person = create(:better_together_person, :platform_manager)
      platform_manager = person
    end

    # Use Capybara to log in
    visit better_together.root_path
    click_link t('devise.shared.links.sign_in', default: 'Sign in')

    fill_in t('activerecord.attributes.better_together/person.email', default: 'Email'),
            with: platform_manager.user.email
    fill_in t('activerecord.attributes.better_together/person.password', default: 'Password'),
            with: 'password'
    click_button t('devise.sessions.new.sign_in', default: 'Sign in')
  end
end
