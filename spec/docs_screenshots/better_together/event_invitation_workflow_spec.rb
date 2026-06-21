# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for event invitation workflow',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'private', requires_invitation: true)
    end
  end
  let!(:manager) { BetterTogether::User.find_by!(email: 'manager@example.test') }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after do
    Current.platform = nil
  end

  it 'captures event invitation access for an invitee with a valid token' do
    event = create(
      :better_together_event,
      platform: host_platform,
      creator: manager.person,
      privacy: 'private',
      name: 'Invitation Review Session'
    )
    invitation = create(
      :better_together_event_invitation,
      invitable: event,
      inviter: manager.person,
      invitee_email: 'alex.applicant@example.test'
    )

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'event_invitation_review_access',
      device: :both,
      metadata: screenshot_metadata(flow: 'event_invitation_review', role: 'invitee')
    ) do
      visit better_together.event_path(
        event,
        locale: I18n.default_locale,
        invitation_token: invitation.token
      )

      expect(page).to have_text('Invitation Review Session')
      expect(page).to have_text('Invitation')
      expect(page).to have_button('Accept')
      expect(page).to have_button('Decline')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/event_invitation_review_access.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/event_invitation_review_access.png')
  end

  it 'captures the event invitation management panel for organizers' do
    event = create(
      :better_together_event,
      platform: host_platform,
      creator: manager.person,
      privacy: 'private',
      name: 'Organizer Invitation Review Session'
    )
    create(
      :better_together_event_invitation,
      invitable: event,
      inviter: manager.person,
      invitee_email: 'alex.applicant@example.test'
    )

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'event_invitation_management_panel',
      device: :both,
      metadata: screenshot_metadata(flow: 'event_invitation_management', role: 'event_organizer')
    ) do
      capybara_login_as_platform_manager
      visit better_together.event_path(event, locale: I18n.default_locale)

      find('#invitations-tab').click

      expect(page).to have_text('Invite People')
      expect(page).to have_text('Invite Member')
      expect(page).to have_text('Invite by Email')
      expect(page).to have_text('alex.applicant@example.test')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/event_invitation_management_panel.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/event_invitation_management_panel.png')
  end

  private

  def screenshot_metadata(flow:, role:)
    {
      locale: I18n.default_locale,
      role: role,
      feature_set: 'event_invitation_workflow',
      flow: flow,
      source_spec: self.class.metadata[:file_path]
    }
  end
end
