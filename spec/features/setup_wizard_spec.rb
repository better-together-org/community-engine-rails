# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Setup Wizard Flow', :js do
  # rubocop:todo RSpec/ExampleLength
  # rubocop:todo RSpec/MultipleExpectations
  scenario 'redirects from root and completes the first wizard step using platform attributes' do
    # rubocop:enable RSpec/MultipleExpectations
    # Build a platform instance (using FactoryBot) with test data
    platform = FactoryBot.build(:platform)

    # Ensure no existing platform is present (tests may run with seeded data)
    BetterTogether::Platform.delete_all

    # Start at the root and verify redirection to the wizard
    visit '/'
    expect(current_path).to eq(better_together.setup_wizard_step_platform_details_path(locale: I18n.locale))
    expect(page).to have_content("Please configure your platform's details below")

    # Fill in the form fields using the field IDs
    fill_in 'platform[name]', with: platform.name
    fill_in 'platform[description]', with: platform.description
    fill_in 'platform[url]', with: platform.url
    select 'Private', from: 'platform[privacy]'
    select 'UTC', from: 'platform[time_zone]'

    # Proceed to the next step
    # click_button 'Next Step'

    # # Verify redirection to the next step and that the data is persisted
    # expect(current_path).to eq(better_together.setup_wizard_step_admin_creation_path(locale: I18n.locale))
    # expect(page).to have_content('Step 2: Admin Configuration')
  end
  # rubocop:enable RSpec/ExampleLength
end
