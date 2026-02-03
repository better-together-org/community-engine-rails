# frozen_string_literal: true

# Provides unique test data generators to prevent conflicts in parallel test execution
module UniqueTestData
  # Generate a unique email address for testing
  # @return [String] unique email in format "test-{uuid}@example.com"
  def unique_email
    "test-#{SecureRandom.uuid}@example.com"
  end

  # Generate a unique OAuth UID for testing
  # @return [String] unique UID in format "oauth-{uuid}"
  def unique_oauth_uid
    "oauth-#{SecureRandom.uuid}"
  end

  # Generate a unique identifier with optional prefix
  # @param prefix [String] optional prefix for the identifier
  # @return [String] unique identifier in format "{prefix}-{hex}"
  def unique_identifier(prefix = 'test')
    "#{prefix}-#{SecureRandom.hex(10)}"
  end

  # Generate a unique username/handle for testing
  # @return [String] unique username in format "user-{hex}"
  def unique_username
    "user-#{SecureRandom.hex(8)}"
  end

  # Generate a unique community/organization name
  # @return [String] unique name in format "Test Community {uuid}"
  def unique_community_name
    "Test Community #{SecureRandom.uuid}"
  end
end

RSpec.configure do |config|
  config.include UniqueTestData
end
