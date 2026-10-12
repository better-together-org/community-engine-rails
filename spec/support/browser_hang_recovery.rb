# frozen_string_literal: true

# A Chrome or chromedriver that stops answering makes every later command time out (Net::ReadTimeout), so the
# rspec-rebound retries reuse the dead session and fail the same way (one example took 482s across 3 attempts).
# After a js example fails on a timeout, discard the browser so the next attempt starts a fresh one.
module BrowserHangRecovery
  class << self
    def hung?(error)
      return false unless error

      errors = error.respond_to?(:all_exceptions) ? error.all_exceptions : [error]
      errors.any?(Timeout::Error)
    end

    def discard_browser
      driver = Capybara.current_session.driver
      driver.quit if driver.respond_to?(:quit)
    rescue StandardError => e
      warn "[browser-hang-recovery] could not discard browser: #{e.class}: #{e.message}"
    end
  end
end

RSpec.configure do |config|
  # Declared after capybara/rspec's own after hook, so it runs first and the session reset cannot hang on a dead browser.
  config.after(:each, :js) do |example|
    BrowserHangRecovery.discard_browser if BrowserHangRecovery.hung?(example.exception)
  end
end
