# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'device permissions settings panel', :accessibility, :js, retry: 0 do
  include BetterTogether::DeviseSessionHelpers

  before do
    platform = configure_host_platform
    platform.update!(feature_gate_rollouts: { 'device_permissions' => 'stable' })
    login_as_platform_manager

    visit settings_path(locale: I18n.default_locale)
    find('#device-permissions-tab', wait: 10).click
    find('#device-permissions.active', wait: 10)
  end

  it 'renders all four permission controls with an accessible status indicator each' do
    within('#device-permissions') do
      expect(page).to have_css('[data-better_together--device-permissions-target="geolocationButton"]')
      expect(page).to have_css('[data-better_together--device-permissions-target="notificationsButton"]')
      expect(page).to have_css('[data-better_together--device-permissions-target="cameraButton"]')
      expect(page).to have_css('[data-better_together--device-permissions-target="microphoneButton"]')

      # Camera and microphone requests are not wired to a real getUserMedia
      # prompt yet (handleCameraPermission/handleMicrophonePermission are
      # stubs) — the buttons are intentionally disabled so they don't imply
      # a capability that isn't implemented.
      expect(page).to have_css('[data-better_together--device-permissions-target="cameraButton"][disabled]')
      expect(page).to have_css('[data-better_together--device-permissions-target="microphoneButton"][disabled]')

      # The Stimulus controller's connect() calls updatePermissionStatus for
      # each target, replacing the initial markup with a status icon + a
      # visually-hidden label. We only assert it ran successfully (produced
      # a FontAwesome icon), not which exact granted/denied/unknown state —
      # that depends on the browser's permission defaults, which vary by CI
      # environment and aren't something this spec should pin down.
      %w[geolocationStatus notificationsStatus cameraStatus microphoneStatus].each do |target|
        status_el = find("[data-better_together--device-permissions-target=\"#{target}\"]", wait: 10)
        expect(status_el).to have_css('i.fa-solid')
      end
    end
  end

  it 'shows a flash prompt when requesting geolocation access' do
    within('#device-permissions') do
      find('[data-better_together--device-permissions-target="geolocationButton"]').click
    end

    expect(page).to have_css('.alert', wait: 10)
  end

  it 'passes WCAG 2.1 AA on the device permissions panel' do
    expect(page).to be_axe_clean
      .within('#device-permissions')
      .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end
end
