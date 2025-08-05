# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'notification badge', type: :feature do
  include BetterTogether::DeviseSessionHelpers

  before do
    configure_host_platform
    login_as_platform_manager
  end

  it 'updates badge and title based on unread count', :js do
    visit conversations_path(locale: I18n.default_locale)
    original_title = page.title

    page.evaluate_async_script(<<~JS)
      const done = arguments[0];
      import('better_together/notifications').then(m => {
        m.updateUnreadNotifications(3);
        done();
      });
    JS

    expect(page).to have_css('#person_notification_count', text: '3')
    expect(page.title).to eq("(3) #{original_title}")

    page.evaluate_async_script(<<~JS)
      const done = arguments[0];
      import('better_together/notifications').then(m => {
        m.updateUnreadNotifications(0);
        done();
      });
    JS

    expect(page).to have_no_css('#person_notification_count')
    expect(page.title).to eq(original_title)
  end

  it 'shows unread status in title and favicon on initial load', :js do
    person = BetterTogether::User.find_by(email: 'manager@example.test').person
    create(:noticed_notification, recipient: person)

    visit conversations_path(locale: I18n.default_locale)

    expect(page).to have_title(/^\(1\)/)
    expect(page).to have_css("link[rel~='icon'][href^='data:image']", visible: false)
  end
end
# rubocop:enable Metrics/BlockLength
