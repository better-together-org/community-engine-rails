# frozen_string_literal: true

require 'capybara/rspec'
require 'tmpdir'

Capybara.server = :puma, { Silent: true }
Capybara.server_host = '127.0.0.1'
Capybara.always_include_port = true

Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Options.chrome(
    args: %w[
      headless
      disable-gpu
      no-sandbox
      disable-dev-shm-usage
      window-size=1400x1400
      disable-features=BlockThirdPartyCookies
    ]
  )
  # Generate a unique temporary directory for each session to avoid conflicts
  options.add_argument("--user-data-dir=#{Dir.mktmpdir}")
  options.binary = '/usr/bin/chromium-browser'
  service = Selenium::WebDriver::Service.chrome(path: '/usr/bin/chromedriver')

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options: options,
    service: service
  )
end

Capybara.javascript_driver = :selenium_chrome_headless

# Align asset_host to the actual server host/port to avoid cross-origin issues
RSpec.configure do |config|
  config.before(:each, type: :feature) do
    host = Capybara.server_host || '127.0.0.1'
    port = Capybara.server_port
    Capybara.asset_host = "http://#{host}:#{port}"
  end
end
