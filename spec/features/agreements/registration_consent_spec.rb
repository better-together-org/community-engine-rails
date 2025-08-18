# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User registration agreements' do
  include BetterTogether::DeviseSessionHelpers

  # rubocop:todo RSpec/LetSetup
  let!(:privacy_agreement) { BetterTogether::Agreement.find_by!(identifier: 'privacy_policy') }
  # rubocop:enable RSpec/LetSetup
  # rubocop:todo RSpec/LetSetup
  let!(:tos_agreement) { BetterTogether::Agreement.find_by!(identifier: 'terms_of_service') }
  # rubocop:enable RSpec/LetSetup

  before do
    configure_host_platform
  end

  it 'requires accepting agreements during sign up' do # rubocop:todo RSpec/ExampleLength
    visit new_user_registration_path(locale: I18n.default_locale)

    fill_in 'user[email]', with: 'test@example.test'
    fill_in 'user[password]', with: 'password12345'
    fill_in 'user[password_confirmation]', with: 'password12345'
    fill_in 'user[person_attributes][name]', with: 'Test User'
    fill_in 'user[person_attributes][identifier]', with: 'testuser'
    fill_in 'user[person_attributes][description]', with: 'Tester'

    click_button 'Sign Up'

    expect(page).to have_content('You must accept the Privacy Policy and Terms of Service')
  end

  # rubocop:todo RSpec/MultipleExpectations
  it 'creates agreement participants when agreements are accepted' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    visit new_user_registration_path(locale: I18n.default_locale)

    fill_in 'user[email]', with: 'test@example.test'
    fill_in 'user[password]', with: 'password12345'
    fill_in 'user[password_confirmation]', with: 'password12345'
    fill_in 'user[person_attributes][name]', with: 'Test User'
    fill_in 'user[person_attributes][identifier]', with: 'testuser'
    fill_in 'user[person_attributes][description]', with: 'Tester'

    check 'terms_of_service_agreement'
    check 'privacy_policy_agreement'

    click_button 'Sign Up'

    user = BetterTogether::User.find_by(email: 'test@example.test')
    expect(user).to be_present
    expect(user.person.agreement_participants.count).to eq(2)
  end
end
