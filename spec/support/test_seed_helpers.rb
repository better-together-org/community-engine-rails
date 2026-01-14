# frozen_string_literal: true

# Ensure commonly referenced test users exist for request specs.
# Uses atomic find_or_create_by to handle parallel test execution safely.
RSpec.configure do |config|
  config.before(:suite) do
    manager_email = 'manager@example.test'
    user_email = 'user@example.test'
    default_password = 'SecureTest123!@#'

    # Atomic database operation - safe for parallel test execution
    BetterTogether::User.find_or_create_by!(email: manager_email) do |user|
      user.password = default_password
      user.password_confirmation = default_password
      user.confirmed_at = Time.current
    end

    BetterTogether::User.find_or_create_by!(email: user_email) do |user|
      user.password = default_password
      user.password_confirmation = default_password
      user.confirmed_at = Time.current
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
    # Another parallel process already created these users - that's fine
    Rails.logger.debug("Test seed users already exist: #{e.message}")
  end
end
