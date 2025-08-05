# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.feature 'User Registration', type: :feature do
  # Ensure you have a valid user created; using FactoryBot here
  let!(:host_platform) { create(:better_together_platform, :host) }
  let!(:host_setup_wizard) do
    BetterTogether::Wizard.find_or_create_by(identifier: 'host_setup')
  end
  let!(:user) { build(:better_together_user) }
  let!(:person) { build(:better_together_person) }
  let!(:privacy_agreement) { create(:agreement, identifier: 'privacy_policy', title: 'Privacy Policy') }
  let!(:tos_agreement) { create(:agreement, identifier: 'terms_of_service', title: 'Terms of Service') }
  let!(:privacy_term) do
    create(:agreement_term, agreement: privacy_agreement, summary: 'We respect your privacy.', position: 1)
  end
  let!(:tos_term) do
    create(:agreement_term, agreement: tos_agreement, summary: 'Be excellent to each other.', position: 1)
  end

  scenario 'User registers successfully' do
    host_setup_wizard.mark_completed
    # byebug
    # Visit the sign-in page (adjust the path if your routes differ)
    visit better_together.new_user_registration_path

    # Fill in the Devise login form
    fill_in 'user[email]', with: user.email
    fill_in 'user[password]', with: user.password
    fill_in 'user[password_confirmation]', with: user.password

    fill_in 'user[person_attributes][name]', with: person.name
    fill_in 'user[person_attributes][identifier]', with: person.identifier

    check 'user_accept_terms_of_service'
    check 'user_accept_privacy_policy'

    # Click the login button (make sure the button text matches your view)
    click_button 'Sign Up'

    # Expect a confirmation message (this text may vary based on your flash messages)
    # rubocop:disable Layout/LineLength
    expect(page).to have_content('A message with a confirmation link has been sent to your email address. Please follow the link to activate your account')
    # rubocop:enable Layout/LineLength
    expect(page).to have_content('Sign In')
    expect(BetterTogether::AgreementParticipant.count).to eq(2)
  end
end
# rubocop:enable Metrics/BlockLength
