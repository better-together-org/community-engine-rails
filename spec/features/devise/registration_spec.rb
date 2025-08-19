# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.feature 'User Registration' do # rubocop:todo RSpec/MultipleMemoizedHelpers
  # Ensure you have a valid user created; using FactoryBot here
  let!(:host_platform) { create(:better_together_platform, :host) } # rubocop:todo RSpec/LetSetup
  let!(:host_setup_wizard) do
    BetterTogether::Wizard.find_or_create_by(identifier: 'host_setup')
  end
  let!(:user) { build(:better_together_user) }
  let!(:person) { build(:better_together_person) }
  let!(:privacy_agreement) do
    BetterTogether::Agreement.find_or_create_by(identifier: 'privacy_policy') do |a|
      a.title = 'Privacy Policy'
    end
  end
  let!(:tos_agreement) do
    BetterTogether::Agreement.find_or_create_by(identifier: 'terms_of_service') do |a|
      a.title = 'Terms of Service'
    end
  end
  let!(:code_of_conduct_agreement) do
    BetterTogether::Agreement.find_or_create_by(identifier: 'code_of_conduct') do |a|
      a.title = 'Code of Conduct'
    end
  end
  let!(:privacy_term) do # rubocop:todo RSpec/LetSetup
    create(:agreement_term, agreement: privacy_agreement, summary: 'We respect your privacy.', position: 1)
  end
  let!(:tos_term) do # rubocop:todo RSpec/LetSetup
    create(:agreement_term, agreement: tos_agreement, summary: 'Be excellent to each other.', position: 1)
  end
  let!(:code_of_conduct_term) do # rubocop:todo RSpec/LetSetup
    create(:agreement_term, agreement: code_of_conduct_agreement, summary: 'Treat everyone with respect and kindness.',
                            position: 1)
  end

  # rubocop:todo RSpec/MultipleExpectations
  scenario 'User registers successfully' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
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

    if page.has_unchecked_field?('terms_of_service_agreement')
      check 'terms_of_service_agreement'
    elsif page.has_unchecked_field?('user_accept_terms_of_service')
      check 'user_accept_terms_of_service'
    end

    if page.has_unchecked_field?('privacy_policy_agreement')
      check 'privacy_policy_agreement'
    elsif page.has_unchecked_field?('user_accept_privacy_policy')
      check 'user_accept_privacy_policy'
    end

    if page.has_unchecked_field?('code_of_conduct_agreement')
      check 'code_of_conduct_agreement'
    elsif page.has_unchecked_field?('user_accept_code_of_conduct')
      check 'user_accept_code_of_conduct'
    end

    # Click the login button (make sure the button text matches your view)
    click_button 'Sign Up'

    # Expect a confirmation message (this text may vary based on your flash messages)
    # rubocop:disable Layout/LineLength
    expect(page).to have_content('A message with a confirmation link has been sent to your email address. Please follow the link to activate your account')
    # rubocop:enable Layout/LineLength
    expect(page).to have_content('Sign In')
    expect(BetterTogether::AgreementParticipant.count).to eq(3)
  end
end
# rubocop:enable Metrics/BlockLength
