# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Setup Wizard completion' do
  let!(:wizard) { BetterTogether::Wizard.find_by!(identifier: 'host_setup') }

  before do
    wizard.mark_completed
  end

  it 'redirects to the success path with notice preserved' do
    get better_together.setup_wizard_path(locale: I18n.locale)
    expect(response).to redirect_to(wizard.success_path)

    # The controller preserves the notice in the flash; assert it directly
    expect(flash[:notice]).to eq(wizard.success_message)
  end

  context 'when a signed in user requests a completed wizard step' do
    let(:step_path) do
      better_together.setup_wizard_step_platform_details_path(locale: I18n.locale)
    end

    it 'redirects to the success path without remembering the step as a return location' do
      get step_path

      expect(response).to redirect_to(wizard.success_path)
      expect(session['user_return_to']).to be_nil
    end

    it 'does not bounce between the wizard step and the sign-in page' do
      get step_path
      get better_together.new_user_session_path(locale: I18n.locale)

      expect(response).not_to redirect_to(step_path)
    end
  end
end
