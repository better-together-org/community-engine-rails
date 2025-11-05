# frozen_string_literal: true

# Ensure commonly referenced test users exist for request specs.
RSpec.configure do |config|
  config.before(:suite) do
    manager_email = 'manager@example.test'
    user_email = 'user@example.test'

    unless BetterTogether::User.find_by(email: manager_email)
      person = BetterTogether::Person.create!(name: 'Manager Person')
      BetterTogether::User.create!(email: manager_email, password: 'SecureTest123!@#', person: person)
    end

    unless BetterTogether::User.find_by(email: user_email)
      person = BetterTogether::Person.create!(name: 'Test User')
      BetterTogether::User.create!(email: user_email, password: 'SecureTest123!@#', person: person)
    end
  end
end
