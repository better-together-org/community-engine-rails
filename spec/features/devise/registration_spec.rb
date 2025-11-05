# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.feature 'User Registration', :user_registration do
  # Ensure you have a valid user created; using FactoryBot here
  let!(:host_setup_wizard) do
    BetterTogether::Wizard.find_or_create_by(identifier: 'host_setup')
  end
  let!(:user) { build(:better_together_user, password: 'SecureTest123!@#', password_confirmation: 'SecureTest123!@#') }
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
  let!(:privacy_term) do
    create(:agreement_term, agreement: privacy_agreement, summary: 'We respect your privacy.', position: 1)
  end
  let!(:tos_term) do
    create(:agreement_term, agreement: tos_agreement, summary: 'Be excellent to each other.', position: 1)
  end
  let!(:code_of_conduct_term) do
    create(:agreement_term, agreement: code_of_conduct_agreement, summary: 'Treat everyone with respect and kindness.',
                            position: 1)
  end

  # rubocop:todo RSpec/MultipleExpectations
  scenario 'User registers successfully' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    host_setup_wizard.mark_completed
    # Debug: check that we have the right setup
    puts "Current path before visit: #{current_path}"
    puts "Host platform exists: #{BetterTogether::Platform.find_by(host: true).present?}"
    puts "Wizard completed: #{host_setup_wizard.completed?}"
    # byebug
    # Visit the sign-in page (adjust the path if your routes differ)
    visit better_together.new_user_registration_path
    puts "Current path after visit: #{current_path}"
    puts "Page title: #{page.title}"
    puts "Page has Sign Up: #{page.has_content?('Sign Up')}"

    # Fill in the Devise login form
    fill_in 'user[email]', with: user.email
    fill_in 'user[password]', with: user.password
    fill_in 'user[password_confirmation]', with: user.password

    fill_in 'user[person_attributes][name]', with: person.name
    fill_in 'user[person_attributes][identifier]', with: person.identifier

    puts 'Looking for agreement checkboxes:'
    puts "  terms_of_service_agreement: #{page.has_field?('terms_of_service_agreement')}"
    puts "  privacy_policy_agreement: #{page.has_field?('privacy_policy_agreement')}"
    puts "  code_of_conduct_agreement: #{page.has_field?('code_of_conduct_agreement')}"

    if page.has_unchecked_field?('terms_of_service_agreement')
      puts '  Checking terms_of_service_agreement'
      check 'terms_of_service_agreement'
    elsif page.has_unchecked_field?('user_accept_terms_of_service')
      puts '  Checking user_accept_terms_of_service'
      check 'user_accept_terms_of_service'
    end

    if page.has_unchecked_field?('privacy_policy_agreement')
      puts '  Checking privacy_policy_agreement'
      check 'privacy_policy_agreement'
    elsif page.has_unchecked_field?('user_accept_privacy_policy')
      puts '  Checking user_accept_privacy_policy'
      check 'user_accept_privacy_policy'
    end

    if page.has_unchecked_field?('code_of_conduct_agreement')
      puts '  Checking code_of_conduct_agreement'
      check 'code_of_conduct_agreement'
    elsif page.has_unchecked_field?('user_accept_code_of_conduct')
      puts '  Checking user_accept_code_of_conduct'
      check 'user_accept_code_of_conduct'
    end

    # Click the login button (make sure the button text matches your view)
    puts "Before clicking Sign Up - User count: #{BetterTogether::User.count}"
    puts "Before clicking Sign Up - Page has button: #{page.has_button?('Sign Up')}"
    click_button 'Sign Up'
    puts "After clicking Sign Up - Current path: #{current_path}"
    puts "After clicking Sign Up - User count: #{BetterTogether::User.count}"
    puts "After clicking Sign Up - Person count: #{BetterTogether::Person.count}"
    puts "After clicking Sign Up - Identification count: #{BetterTogether::Identification.count}"
    created_user = BetterTogether::User.last
    puts "Created user ID: #{created_user&.id}"
    puts "Created user has person: #{created_user&.person.present?}"
    puts "Person ID: #{created_user&.person&.id}" if created_user&.person
    puts "Person persisted: #{created_user&.person&.persisted?}" if created_user&.person
    puts "Person errors: #{created_user.person.errors.full_messages}" if created_user&.person&.errors&.any?
    puts "Person identification exists: #{created_user&.person_identification.present?}" if created_user
    if created_user&.person_identification
      puts "Person identification persisted: #{created_user&.person_identification&.persisted?}"
    end

    # Check if person was created separately
    all_persons = BetterTogether::Person.all
    puts "All persons: #{all_persons.map(&:id)}"

    # Check if there are any identifications
    all_identifications = BetterTogether::Identification.all
    puts "All identifications: #{all_identifications.map do |i|
      "#{i.id} -> agent: #{i.agent_type}##{i.agent_id}, identity: #{i.identity_type}##{i.identity_id}"
    end}"
    puts "After clicking Sign Up - AgreementParticipant count: #{BetterTogether::AgreementParticipant.count}"
    puts "After clicking Sign Up - PersonCommunityMembership count: #{BetterTogether::PersonCommunityMembership.count}"
    puts "Page content after submit: #{page.body.include?('error') ? 'CONTAINS ERRORS' : 'NO ERRORS VISIBLE'}"

    # Expect a confirmation message (this text may vary based on your flash messages)
    # rubocop:disable Layout/LineLength
    expect(page).to have_content('A message with a confirmation link has been sent to your email address. Please follow the link to activate your account')
    # rubocop:enable Layout/LineLength
    expect(page).to have_content('Sign In')
    expect(BetterTogether::AgreementParticipant.count).to eq(3)
  end
end
# rubocop:enable Metrics/BlockLength
