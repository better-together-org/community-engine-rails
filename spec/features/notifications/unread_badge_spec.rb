# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'notification badge' do
  context 'with platform manager role' do
    it 'updates badge and title based on unread count', :js do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
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
  end
end
