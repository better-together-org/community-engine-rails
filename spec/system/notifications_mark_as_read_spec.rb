# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'notifications', type: :system do
  include BetterTogether::DeviseSessionHelpers

  before do
    driven_by(:selenium_chrome_headless)
    configure_host_platform
    login_as_platform_manager
  end

  it 'marks notifications as read without reloading and updates counts', :js do
    user = BetterTogether::User.find_by(email: 'manager@example.test')
    conversation = create(:conversation)
    create(:conversation_participant, conversation:, person: user.person)
    other = create(:user, :confirmed)
    create(:conversation_participant, conversation:, person: other.person)
    create_list(:message, 2, conversation:, person: other.person)

    visit notifications_path(locale: I18n.default_locale)

    expect(page).to have_css('#notifications_unread_count', text: '1')
    expect(page).to have_css('#person_notification_count', text: '1')
    expect(page).to have_css('.notification .badge', count: 1)

    all('.notification').last.click

    expect(page).to have_css('#notifications_unread_count', text: '0')
    expect(page).to have_no_css('#person_notification_count')
    expect(page).to have_no_css('.notification .badge')
  end
end
