# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settings feature gates', :no_auth do
  let(:locale) { I18n.default_locale }
  let(:password) { 'SecureTest123!@#' }
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
  let(:regular_user) { create(:better_together_user, :confirmed, password:) }
  let(:manager_user) { create(:better_together_user, :confirmed, :platform_manager, password:) }

  before do
    platform.update!(feature_gate_rollouts: { 'device_permissions' => 'beta' })
  end

  it 'hides beta-only settings tabs from general users' do
    login(regular_user.email, password)

    get better_together.settings_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('device-permissions-tab')
    expect(response.body).not_to include('id="device-permissions"')
  end

  it 'shows beta-only settings tabs to staff with beta feature access' do
    login(manager_user.email, password)

    get better_together.settings_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('device-permissions-tab')
    expect(response.body).to include('id="device-permissions"')
  end
end
