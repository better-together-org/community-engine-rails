# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform theme and colour mode accessibility', :accessibility, :js, retry: 0 do # rubocop:disable RSpec/DescribeClass
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

  before do
    configure_host_platform
    capybara_login_as_platform_manager
    visit better_together.edit_platform_path(locale: I18n.default_locale, id: host_platform.slug)
    find('#platform-appearance-tab').click
    page.has_css?('#platform-appearance.show.active', wait: 10)
  end

  it 'has an axe clean theme picker, preview and mode settings' do
    find('#platform-theme-preview-mode-dark').click
    expect(page).to be_axe_clean.within('#platform-theme-settings').according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end

  it 'has an axe clean colour mode toggle that can be used by keyboard' do
    expect(page).to be_axe_clean.within('#color-mode-toggle').according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
    find('#color-mode-dark').send_keys(:enter)
    expect(page).to have_css('html[data-bs-theme=dark]', wait: 5)
    expect(page).to have_css('#color-mode-dark[aria-pressed=true]')
    expect(find('#color-mode-status', visible: :all).text(:all)).to be_present
  end
end
