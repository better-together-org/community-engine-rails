# frozen_string_literal: true

require 'capybara/rspec'
require 'tmpdir'

Capybara.server = :puma, { Silent: true }

Capybara.register_driver :selenium_headless_chrome do |app|
  options = Selenium::WebDriver::Options.chrome(
    args: %w[
      headless
      disable-gpu
      no-sandbox
      disable-dev-shm-usage
      window-size=1400x1400
    ]
  )
  # Generate a unique temporary directory for each session to avoid conflicts
  options.add_argument("--user-data-dir=#{Dir.mktmpdir}")

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options: options
  )
end

Capybara.javascript_driver = :selenium_headless_chrome
