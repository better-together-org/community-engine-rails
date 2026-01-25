# frozen_string_literal: true

require 'capybara/rspec'
require 'tmpdir'

Capybara.server = :puma, { Silent: true }
Capybara.server_host = '127.0.0.1'
Capybara.always_include_port = true

Capybara.register_driver :selenium_chrome_headless do |app|
  # Generate a unique temporary directory for each session to avoid conflicts in parallel execution
  # Include process ID and timestamp for better uniqueness across parallel workers
  user_data_dir = Dir.mktmpdir("chrome-#{Process.pid}-#{Time.now.to_i}-")

  # Also set a unique remote debugging port for parallel execution
  # Use a range based on process ID to avoid conflicts
  remote_debugging_port = 9222 + (Process.pid % 1000)

  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = '/usr/bin/chromium'
  options.add_argument('--headless')
  options.add_argument('--disable-gpu')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1400,1400')
  options.add_argument('--disable-features=BlockThirdPartyCookies')
  options.add_argument("--user-data-dir=#{user_data_dir}")
  options.add_argument("--remote-debugging-port=#{remote_debugging_port}")

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options: options
  )
end

Capybara.javascript_driver = :selenium_chrome_headless
Capybara.default_driver = :rack_test

# Align asset_host to the actual server host/port to avoid cross-origin issues
RSpec.configure do |config|
  config.before(:each, type: :feature) do
    host = Capybara.server_host || '127.0.0.1'
    port = Capybara.server_port
    Capybara.asset_host = "http://#{host}:#{port}"
  end
end
