# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/mobile_navbar_dropdowns_spec.rb
#
# On a phone-sized window every header dropdown must open fully inside the viewport. Bootstrap positions a menu
# against its own <li> inside .navbar-nav, so a wide menu used to hang off a small icon and run off-screen.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for mobile navbar dropdowns', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', requires_invitation: false) }
  end
  let(:dropdowns) do
    {
      'notifications' => { toggle: '#notification-icon', menu: '#notification-list' },
      'locale' => { toggle: '#localeDropdownMenuLink', menu: '#locale-switcher .dropdown-menu' },
      'user' => { toggle: '#userNavbarDropdownMenuLink', menu: '#userNavbarDropdownMenuLink + .dropdown-menu' }
    }
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    manager
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'mobile_navbar_dropdowns', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def open_dropdown(name)
    capybara_login_as_platform_manager
    visit better_together.home_page_path(locale: I18n.default_locale)
    toggle, menu = dropdowns.fetch(name).values_at(:toggle, :menu)
    find(toggle, match: :first).click
    expect(page).to have_css("#{menu}.show", wait: 10)
    fill_notifications if name == 'notifications'
    sleep 0.3
  end

  # Stand-in for the lazily loaded list so the menu is as tall as a real inbox.
  def fill_notifications
    page.execute_script(<<~JS)
      const target = document.querySelector('[data-better-together--lazy-notifications-target="content"]');
      target.innerHTML = Array.from({ length: 6 }, (_, i) =>
        '<div class="notification mb-3"><h5>New membership request ' + (i + 1) + ' for a community</h5>' +
        '<p>Someone asked to join the community and is waiting for review.</p></div>').join('');
    JS
  end

  def menu_edges(name)
    page.evaluate_script(<<~JS)
      (function () {
        const rect = document.querySelector(#{dropdowns.fetch(name)[:menu].to_json}).getBoundingClientRect();
        return { left: rect.left, right: rect.right, width: window.innerWidth };
      })()
    JS
  end

  %w[notifications locale user].each do |name|
    it "opens the #{name} dropdown inside the mobile viewport", :aggregate_failures do
      edges = nil
      BetterTogether::CapybaraScreenshotEngine.capture(
        "mobile_navbar_#{name}_dropdown", device: :mobile, metadata: metadata("mobile_navbar_#{name}_dropdown"),
                                          callouts: [{ selector: dropdowns.fetch(name)[:menu],
                                                       title: "#{name.capitalize} menu",
                                                       bullets: ['Opens within the screen edges.'] }]
      ) do
        open_dropdown(name)
        edges = menu_edges(name)
      end

      expect(edges['left']).to be >= 0
      expect(edges['right']).to be <= edges['width']
    end

    it "captures the unannotated #{name} dropdown" do
      BetterTogether::CapybaraScreenshotEngine.capture(
        "mobile_navbar_#{name}_dropdown_plain", device: :mobile,
                                                metadata: metadata("mobile_navbar_#{name}_dropdown_plain")
      ) do
        open_dropdown(name)
        expect(page).to have_css("#{dropdowns.fetch(name)[:menu]}.show")
      end
    end
  end
end
