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
end
