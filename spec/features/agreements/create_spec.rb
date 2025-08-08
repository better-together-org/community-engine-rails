# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'managing agreements', type: :feature do
  include BetterTogether::DeviseSessionHelpers

  before do
    configure_host_platform
    login_as_platform_manager
  end

  scenario 'platform manager creates a new agreement' do
    visit new_agreement_path(locale: I18n.default_locale)
    fill_in 'agreement[title_en]', with: 'Test Agreement'
    select 'Public', from: 'agreement[privacy]'
    click_button 'Create Agreement'

    expect(page).to have_content('Agreement was successfully created')
    expect(page).to have_content('Test Agreement')
  end

  scenario 'agreement appears on index' do
    create(:agreement, title: 'Existing Agreement', slug: 'existing-agreement', privacy: 'public')

    visit agreements_path(locale: I18n.default_locale)
    expect(page).to have_content('Existing Agreement')
  end
end
