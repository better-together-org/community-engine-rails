# frozen_string_literal: true

# Ensure commonly referenced test users exist for request specs.
RSpec.configure do |config|
  config.before(:suite) do
    manager_email = 'manager@example.test'
    user_email = 'user@example.test'

    unless BetterTogether::User.find_by(email: manager_email)
      FactoryBot.create(:better_together_user, :confirmed, email: manager_email)
    end

    unless BetterTogether::User.find_by(email: user_email)
      FactoryBot.create(:better_together_user, :confirmed, email: user_email)
    end
  end
end
