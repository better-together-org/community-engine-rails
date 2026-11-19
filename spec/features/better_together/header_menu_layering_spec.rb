# frozen_string_literal: true

require 'rails_helper'

# Flash alerts sit above the page content but below an open header menu, so a "saved" notice never hides the menu
# someone just opened. Checked with the engine styles alone and under a host stylesheet that sets its own header
# stacking order (the Better Together host app puts #main-nav at z-index 1000).
RSpec.describe 'Header menu and flash alert layering', :js, :no_auth, :skip_host_setup, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', requires_invitation: false) }
  end

  before do
    Current.platform = host_platform
    manager
  end

  after { Current.platform = nil }

  def show_flash
    page.execute_script(<<~JS)
      const alert = document.createElement('div');
      alert.id = 'spec-flash'; alert.className = 'alert alert-success text-center'; alert.setAttribute('role', 'alert');
      alert.innerHTML = 'Preference saved successfully<br>Second line<br>Third line<br>Fourth line<br>Fifth line';
      document.querySelector('#col-flash-message').replaceChildren(alert);
    JS
  end

  def host_header_css
    page.execute_script(<<~JS)
      const style = document.createElement('style');
      style.textContent = '#main-nav { position: sticky; top: 0; z-index: 1000; }';
      document.head.appendChild(style);
    JS
  end

  # For each item in the menu: whether the topmost element at its centre belongs to the menu, and whether the alert
  # overlaps it at all (so the check is not passing only because they never meet).
  def layering(menu)
    page.evaluate_script(<<~JS)
      (function(){ const menu = document.querySelector(#{menu.to_json}); const alert = document.querySelector('#spec-flash').getBoundingClientRect();
        const shown = Array.from(menu.querySelectorAll('.dropdown-item')).filter((item) => item.getBoundingClientRect().width > 0);
        return shown.map((item) => { const r = item.getBoundingClientRect();
          const x = r.left + r.width / 2, y = r.top + r.height / 2; const top = document.elementFromPoint(x, y);
          const overlaps = r.bottom > alert.top && r.top < alert.bottom && r.right > alert.left && r.left < alert.right;
          return { label: item.textContent.trim(), onTop: !!top && menu.contains(top), overlaps }; }); })()
    JS
  end

  def alert_on_top_of_content?
    page.evaluate_script(<<~JS)
      (function(){ const r = document.querySelector('#spec-flash').getBoundingClientRect();
        const top = document.elementFromPoint(r.left + 8, r.bottom - 4); return !!top && !!top.closest('#spec-flash'); })()
    JS
  end

  { 'engine styles' => false, 'a host header stacking order' => true }.each do |label, host_css|
    { 'desktop' => [1280, 900], 'mobile' => [390, 844] }.each do |device, (width, height)|
      it "keeps open header menus above a flash alert under #{label} on #{device}" do # rubocop:disable RSpec/MultipleExpectations
        page.current_window.resize_to(width, height)
        capybara_login_as_platform_manager
        visit better_together.settings_path(locale: I18n.default_locale)
        host_header_css if host_css
        show_flash
        expect(alert_on_top_of_content?).to be(true)

        { '#localeDropdownMenuLink' => '#locale-switcher .dropdown-menu',
          '#userNavbarDropdownMenuLink' => '#user-nav > .dropdown-menu' }.each do |toggle, menu|
          find(toggle).click
          expect(page).to have_css("#{menu}.show")
          items = layering(menu)
          expect(items.any? { |item| item['overlaps'] }).to be(true), "#{menu} never meets the alert"
          expect(items.reject { |item| item['onTop'] }.pluck('label')).to be_empty
        end
      end
    end
  end
end
