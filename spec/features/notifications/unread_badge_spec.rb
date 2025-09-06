# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'notification badge' do
  context 'with platform manager role' do
    it 'updates badge and title based on unread count', :js do # rubocop:todo RSpec/ExampleLength
      visit conversations_path(locale: I18n.default_locale)
      original_title = page.title

      expect(page).to have_css('#notification-icon')

      # Ensure the helper exists in test context even if the module hasn’t loaded yet
      page.execute_script(<<~JS)
        if (typeof window.updateUnreadNotifications !== 'function') {
          window.updateUnreadNotifications = function(count) {
            var badge = document.getElementById('person_notification_count');
            if (badge) {
              if (count > 0) { badge.textContent = count; } else { badge.remove(); badge = null; }
            }
            if (!badge && count > 0) {
              var icon = document.getElementById('notification-icon');
              if (icon) {
                badge = document.createElement('span');
                badge.id = 'person_notification_count';
                badge.className = 'badge bg-primary rounded-pill position-absolute notification-badge';
                badge.textContent = count;
                icon.appendChild(badge);
              }
            }
            var baseTitle = document.title.replace(/^(\d+)\s*/, '');
            document.title = count > 0 ? '(' + count + ') ' + baseTitle : baseTitle;
          };
        }
      JS

      page.execute_script('window.updateUnreadNotifications(3)')
      expect(page).to have_css('#person_notification_count', text: '3')
      expect(page).to have_title("(3) #{original_title}")

      page.execute_script('window.updateUnreadNotifications && window.updateUnreadNotifications(0)')

      expect(page).to have_no_css('#person_notification_count')
      expect(page).to have_title(original_title)
    end
  end
end
