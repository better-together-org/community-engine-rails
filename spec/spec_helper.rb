# frozen_string_literal: true

require 'capybara/rspec'
require 'capybara-screenshot/rspec'
require 'rspec/rebound'
require 'webmock/rspec'
require 'parallel_rspec'

# Disable real external HTTP connections in tests but allow localhost so
# Capybara drivers (cuprite/ferrum/selenium) can communicate with the app
# server started by the test suite. Also allow Elasticsearch connections.
WebMock.disable_net_connect!(allow_localhost: true, allow: 'elasticsearch:9200')

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
end

Capybara.asset_host = ENV.fetch('APP_HOST', 'http://localhost:3000')
