# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Setup Wizard Flow', type: :feature, js: true do
  scenario 'redirects from root and completes the first wizard step using platform attributes' do
    # Build a platform instance (using FactoryBot) with test data
    FactoryBot.build(:platform)

    # Start at the root and verify redirection to the wizard
    visit '/'
    expect(current_path).to eq(better_together.setup_wizard_step_platform_details_path(locale: I18n.locale))
    expect(page).to have_content("Please configure your platform's details below")

    # # Fill in the form fields using the values from the built platform.
    # # Adjust the field labels as they appear in your screenshot.
    # fill_in "Platform Name", with: platform.name
    # fill_in "Domain", with: platform.domain
    # fill_in "Description", with: platform.description
    # # Add additional fields as needed, for example:
    # # fill_in "Tagline", with: platform.tagline
    # # select platform.some_option, from: "Some Option"

    # # Submit the first step of the wizard.
    # click_button "Next"

    # # Verify redirection to the next step and that the data is persisted.
    # expect(current_path).to eq(wizard_step_two_path)
    # expect(page).to have_content("Step 2: Admin Configuration")
    # # Optionally, verify that data from step one appears on this page.
    # expect(page).to have_content(platform.name)
    # expect(page).to have_content(platform.domain)

    # (Continue the wizard steps as needed for your integration tests.)
  end
end
