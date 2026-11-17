# frozen_string_literal: true

require 'rails_helper'

# Saving a theme in Preferences repaints the page in place, every time: switching back to a theme chosen earlier,
# returning to the platform theme and following a link afterwards all show the theme that was saved last.
RSpec.describe 'Applying a personal theme in place', :js, :no_auth, :skip_host_setup, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers

  let(:cfg) { BetterTogether::PlatformThemeConfig }
  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_user_themes: true,
                       theme: cfg.flat_theme('neutral').merge('preset' => 'neutral'))
    end
  end

  before do
    Current.platform = host_platform
    manager.person.update!(color_mode: 'light')
  end

  after do
    host_platform.update!(theme: {})
    Current.platform = nil
  end

  def rgb(hex) = "rgb(#{hex.delete('#').scan(/../).map { |pair| pair.to_i(16) }.join(', ')})"

  def save_theme(value)
    find('#person_theme').find("option[value='#{value}']").select_option
    find('#person_theme').ancestor('.preference-field-wrapper').find('button.btn-success').click
  end

  def page_state
    page.evaluate_script(<<~JS)
      ({ bg: getComputedStyle(document.body).backgroundColor, styles: document.querySelectorAll('#user-theme-style').length,
         platform: document.querySelectorAll('#platform-theme-style').length,
         attr: document.documentElement.getAttribute('data-bts-user-theme') })
    JS
  end

  def expect_theme(id)
    wanted = { 'bg' => rgb(cfg.themes.fetch(id || 'neutral')['page_bg']), 'styles' => id ? 1 : 0, 'platform' => 1, 'attr' => id }
    page.document.synchronize(10) do
      raise Capybara::ExpectationNotMet, "#{page_state} is not #{wanted}" unless page_state == wanted
    end
    expect(page_state).to eq(wanted)
  end

  it 'repaints the page for each saved theme, including one chosen before, and keeps it across navigation' do
    capybara_login_as_platform_manager
    visit better_together.settings_path(locale: I18n.default_locale)
    find('#preferences-tab').click
    expect(page).to have_css('#person_theme', wait: 10)

    %w[warm cool warm].each do |id|
      save_theme(id)
      expect_theme(id)
    end
    save_theme('')
    expect_theme(nil)
    save_theme('cool')
    expect_theme('cool')

    find('#userNavbarDropdownMenuLink').click
    find('#user-nav .dropdown-item[data-identifier="conversations"]').click
    expect(page).to have_current_path(%r{/conversations})
    expect_theme('cool')
  end
end
