# frozen_string_literal: true

require 'capybara/rspec'

Capybara.server = :puma, { Silent: true }

# This will work inside Docker (browser & Rails app both in containers)
Capybara.register_driver :selenium_headless_chrome do |app|
  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options: Selenium::WebDriver::Options.chrome(
      args: %w[
        headless
        disable-gpu
        no-sandbox
        disable-dev-shm-usage
        window-size=1400x1400
      ]
    )
  )
end

Capybara.javascript_driver = :selenium_headless_chrome

# Capybara.server_host = '0.0.0.0' # Needed for Capybara server to bind inside container
# Capybara.app_host = "http://app:3000" # In docker-compose, this should match service name & port
