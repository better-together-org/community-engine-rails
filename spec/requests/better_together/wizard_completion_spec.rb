# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Setup Wizard completion', type: :request do
  let!(:platform) { create(:better_together_platform, :host, privacy: 'private') }
  let!(:wizard) { BetterTogether::Wizard.find_by!(identifier: 'host_setup') }
  let!(:user) { create(:better_together_user, :confirmed, :platform_manager) }

  before do
    wizard.mark_completed
    login_as(user, scope: :user)
  end

  it 'redirects to the success path with notice preserved' do
    get better_together.setup_wizard_path(locale: I18n.locale)
    expect(response).to redirect_to(wizard.success_path)

    follow_redirect!
    expect(response.body).to include(wizard.success_message)
  end
end
