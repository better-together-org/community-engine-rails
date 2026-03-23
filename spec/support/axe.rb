# frozen_string_literal: true

require 'axe-capybara'
require 'axe-rspec'

# Configure axe-capybara to use our existing selenium_chrome_headless driver
# instead of creating its own Chrome instance which causes conflicts in parallel execution
AxeCapybara.configure do |c|
  # Use default axe.js library
  c.skip_iframes = false # Include iframes in accessibility checks
end
